require "application_system_test_case"

class KlassManagementTest < ApplicationSystemTestCase
  test "从班级菜单切换到同科目的其他班级" do
    sign_in
    visit admin_semester_klass_path(semester_klasses(:sk_math_2))

    within(".menu") { click_link semester_klasses(:sk_math_3).name }

    assert_current_path admin_semester_klass_path(semester_klasses(:sk_math_3))
    assert_selector "a.menu-active", text: semester_klasses(:sk_math_3).name
  end

  test "从班级详情复制到下个学期" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    visit admin_semester_klass_path(sk)

    find("label[for='drawer-copy']").click
    within("form[action='#{copy_create_admin_semester_klasses_path}']") do
      click_button "复制到 #{semesters(:semester_next).name}"
    end

    assert_text "复制成功"
    target = SemesterKlass.where(semester: semesters(:semester_next)).order(:id).last
    assert_equal sk.grade, target.grade
    assert target.klass_students.exists?(student_id: students(:student_7_1).id)
    assert_current_path admin_semester_klass_path(sk)
  end

  test "预留下学期并在预留表中生成班级" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    visit admin_semester_klass_path(sk)

    find("input[data-attendance-select-target='rowCheckbox'][value='#{students(:student_7_1).id}']").check
    click_button "预留"

    within("dialog#reserve-modal") do
      assert_selector "[data-attendance-select-target='reserveList']", text: students(:student_7_1).name
      within("form[action='#{reserve_admin_semester_klass_path(sk)}']") do
        select "精英班", from: "班型"
        click_button "确认预留"
      end
    end

    assert_text "已预留 1 名学员"
    # 预留只登记，不直接建班
    assert_equal 0, SemesterKlass.where(semester: semesters(:semester_next)).count

    # 学员年级与班级年级一致才可进班：生成班级前先把学员升级到预留的目标年级
    students(:student_7_1).update!(grade: grades(:grade_8))

    visit switch_thread_semester_admin_semester_path(semesters(:semester_next))
    visit admin_reservations_path
    assert_text "待分班"

    reservation = Reservation.find_by!(student: students(:student_7_1), semester: semesters(:semester_next))
    find("input[data-reservation-select-target='rowCheckbox'][value='#{reservation.id}']").check
    click_button "批量进班"

    within("#batch-enroll-drawer") do
      key = reservation.group_key_string
      # 预留时未指定教师，生成前需在抽屉里为分组选择本科目教师
      within("[data-batch-group='#{key}']") { select "张", from: "教师" }
      click_button "确认进班"
    end

    assert_text "已生成 1 个班级"
    target = SemesterKlass.where(semester: semesters(:semester_next)).order(:id).last
    assert_equal grades(:grade_8), target.grade
    assert target.klass_students.exists?(student_id: students(:student_7_1).id)
  end

  test "考勤表勾选学员后批量移出" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    visit admin_semester_klass_path(sk)

    find("input[data-attendance-select-target='rowCheckbox'][value='#{students(:student_7_1).id}']").check
    click_button "移出"

    within("dialog#remove-modal") do
      assert_selector "[data-attendance-select-target='removeList']", text: students(:student_7_1).name
      click_button "确认移出"
    end

    assert_text "已移出 1 名学员"
    assert klass_students(:ks_2).reload.archived_at.present?
    assert_text "已移出学员"
  end

  test "预留信息图标 hover 弹出卡片且不被遮挡" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    KlassStudent.create!(semester_klass: sk, student: students(:student_7_2), status: "in")
    reservation = Reservation.create!(
      student: students(:student_7_1), semester: semesters(:semester_next), subject: subjects(:math),
      grade: grades(:grade_8), teacher: teachers(:math_teacher_1), genre: "JY",
      source_semester: sk.semester, source_semester_klass: sk
    )
    visit admin_semester_klass_path(sk)

    find("button[aria-label='预留信息']").hover
    card = find("[data-card-kind='reservation'].flex")

    # 卡片位于 sticky 姓名列内，需抬高所在单元格层级才不被后续行盖住
    result = card.evaluate_script(<<~JS)
      ((el) => {
        const th = el.closest("th");
        const probe = () => {
          const r = el.getBoundingClientRect();
          let occluded = 0;
          for (let x = r.left + 30; x < r.right - 30; x += 40)
            for (let y = r.top + 30; y < r.bottom - 30; y += 25)
              if (!el.contains(document.elementFromPoint(x, y))) occluded++;
          return occluded;
        };
        const fixed = probe();
        th.style.zIndex = "10";
        const withoutFix = probe();
        th.style.zIndex = "";
        return { fixed: fixed, withoutFix: withoutFix };
      })(this)
    JS
    assert_operator result["withoutFix"], :>, 0, "探测方法无效：不抬层级时也未检测到遮挡"
    assert_equal 0, result["fixed"], "预留卡片被其他单元格遮挡"

    within(card) do
      assert_selector "form[action='#{admin_reservation_path(reservation)}'] select[name='grade_id']"
      assert_selector "button", text: "取消预留"
    end

    find("th.sticky", match: :first).click
    assert_no_selector "[data-card-kind='reservation'].flex"
  end

  test "预留信息卡片内可直接修改预留" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    reservation = Reservation.create!(
      student: students(:student_7_1), semester: semesters(:semester_next), subject: subjects(:math),
      grade: grades(:grade_7), teacher: teachers(:math_teacher_1), genre: "TG",
      source_semester: sk.semester, source_semester_klass: sk
    )
    visit admin_semester_klass_path(sk)

    find("button[aria-label='预留信息']").hover
    card = find("[data-card-kind='reservation'].flex")
    within(card) do
      select "精英班", from: "班型"
      click_button "保存"
    end
    assert_text "已更新"
    assert_equal "JY", reservation.reload.genre
  end

  test "开班搜索不到学员时可以快速添加并直接选中" do
    sign_in
    visit admin_semester_klasses_path

    find("label[for='drawer-klass-new']").click
    drawer = find("#drawer-klass-new", visible: :all).ancestor(".drawer-end")

    within(drawer) do
      choose_grade "七年级"
      fill_in "搜索学员姓名", with: "新学员"
      assert_text "没有匹配的学员"
      click_button "快速添加学员"
      assert_selector "[data-student-multiselect-target='selected']", text: "新学员", wait: 5
      pick_teacher "张"
      fill_in "课次", with: "3"
      click_button "开班"
    end

    assert_text "班级创建成功"
    created = SemesterKlass.order(:id).last
    assert created.klass_students.exists?(student: Student.find_by!(name: "新学员"))
  end

  test "开班可以粘贴名单导入学员" do
    sign_in
    visit admin_semester_klasses_path

    find("label[for='drawer-klass-new']").click
    drawer = find("#drawer-klass-new", visible: :all).ancestor(".drawer-end")

    within(drawer) do
      choose_grade "七年级"
      choose "粘贴名单"
      fill_in "粘贴名单（每行：姓名,入班课次）", with: "7_学生2,2\n7_学生3\n新粘同学,1\n新粘同学,1"
      pick_teacher "张"
      fill_in "课次", with: "3"
      click_button "开班"
    end

    assert_text "班级创建成功"
    assert_text "新建 1 名学员"
    assert_text "跳过 1 行"
    created = SemesterKlass.order(:id).last
    assert created.klass_students.exists?(student: students(:student_7_2))
    assert created.klass_students.exists?(student: students(:student_7_3))
    newcomer = Student.find_by!(name: "新粘同学")
    assert_equal created.grade, newcomer.grade
    assert created.klass_students.exists?(student: newcomer)
  end

  test "开班可以选择第二阶段" do
    sign_in
    visit admin_semester_klasses_path

    find("label[for='drawer-klass-new']").click
    drawer = find("#drawer-klass-new", visible: :all).ancestor(".drawer-end")

    within(drawer) do
      choose_phase "第二阶段"
      choose_genre "提高班"
      choose_grade "七年级"
      pick_teacher "张"
      fill_in "课次", with: "3"
      click_button "开班"
    end

    assert_text "班级创建成功"
    created = SemesterKlass.order(:id).last
    assert_equal 2, created.phase
    assert_equal "二期7数提1", created.name
    assert_text created.name
  end

  test "班级页操作按钮排在同一行" do
    sign_in
    visit admin_semester_klass_path(semester_klasses(:sk_math_2))

    tops = all("[data-page-actions] > *").map { |el| el.evaluate_script("this.getBoundingClientRect().top") }
    assert_operator tops.max - tops.min, :<=, 4, "按钮未横排：#{tops.inspect}"
  end

  test "班级考勤页可以开班" do
    sign_in
    visit admin_semester_klass_path(semester_klasses(:sk_math_2))

    find("label[for='drawer-klass-new']").click
    drawer = find("#drawer-klass-new", visible: :all).ancestor(".drawer-end")

    within(drawer) do
      choose_genre "提高班"
      choose_grade "七年级"
      pick_teacher "张"
      fill_in "课次", with: "3"
      click_button "开班"
    end

    assert_text "班级创建成功"
    created = SemesterKlass.order(:id).last
    assert_current_path admin_semester_klass_path(created)
    assert_equal 3, created.courses.count
  end

  test "可以选择课次批量开课" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    visit admin_semester_klass_path(sk)

    select "第 3 课", from: "开课到"
    click_button "批量开课"

    assert_text "已开第 1–3 课"
    assert_equal 3, sk.courses.where.not(start_date: nil).count
    # 「开第 N 课」单节按钮已移除；批量开课后「开课到」默认选中下一个未开课课次
    assert_selector "select#through_seq option[selected]", text: "第 4 课"
  end

  test "未开课的班级可以删除" do
    sign_in
    sk = semester_klasses(:sk_math_3)
    visit admin_semester_klass_path(sk)

    accept_confirm(/确定删除班级/) { click_button "删除班级" }

    assert_text "已删除班级 #{sk.name}"
    assert_current_path admin_semester_klasses_path
    assert_not SemesterKlass.exists?(sk.id)
  end

  test "切换年级和教师会持续更新课次默认值" do
    sign_in
    visit admin_semester_klasses_path

    find("label[for='drawer-klass-new']").click
    drawer = find("#drawer-klass-new", visible: :all).ancestor(".drawer-end")

    within(drawer) do
      choose_grade "七年级"
      pick_teacher "张"
      assert_field "课次", with: "16"

      choose_grade "八年级"
      pick_teacher "王"
      assert_field "课次", with: "12"

      choose_grade "七年级"
      assert_field "课次", with: ""
      pick_teacher "张"
      assert_field "课次", with: "16"
    end
  end

  test "在班级管理页开班并生成课次" do
    sign_in
    visit admin_semester_klasses_path

    find("label[for='drawer-klass-new']").click
    drawer = find("#drawer-klass-new", visible: :all).ancestor(".drawer-end")

    within(drawer) do
      choose_genre "精英班"
      choose_grade "七年级"
      pick_teacher "张"
      assert_field "课次", with: "16"
      fill_in "课次", with: "3"
      click_button "开班"
    end

    assert_text "班级创建成功"
    assert_text "一期7数精1"
    assert_equal 3, SemesterKlass.order(:id).last.courses.count
  end

  test "开班抽屉默认选中负责的首个年级和提高班，教师可搜索选择" do
    sign_in
    visit admin_semester_klasses_path

    find("label[for='drawer-klass-new']").click
    drawer = find("#drawer-klass-new", visible: :all).ancestor(".drawer-end")

    within(drawer) do
      assert_checked_field "klass_new_semester_klass_grade_id_#{grades(:grade_7).id}"
      assert_checked_field "klass_new_semester_klass_genre_tg"
      assert_field "教师", with: ""

      # 按科目搜索：列出该科目的全部教师
      fill_in "教师", with: "英语"
      results = find("[data-search-select-target='results']")
      assert results.has_button?("王")
      assert results.has_button?("李")
      assert results.has_no_button?("张")

      # 按姓名搜索后选中，隐藏的 select 同步写入教师 id
      fill_in "教师", with: "李"
      within("[data-search-select-target='results']") { click_button "李" }
      assert_field "教师", with: "李"
      assert_equal teachers(:eng_teacher_2).id.to_s,
        find("select[name='semester_klass[teacher_id]']", visible: :all).value

      # 没有匹配项，且不会留下选不中的自由文本
      fill_in "教师", with: "不存在的老师"
      assert_text "没有匹配的选项"
      find("h3", text: "开班", match: :first).click
      assert_field "教师", with: "李"
    end
  end

  private
    # 开班抽屉里年级、班型、阶段是按钮组，教师是可搜索选择器
    def choose_grade(name)
      choose "klass_new_semester_klass_grade_id_#{Grade.find_by!(name:).id}"
    end

    def choose_genre(name)
      choose "klass_new_semester_klass_genre_#{SemesterKlass::GENRE_MAP.fetch(name).downcase}"
    end

    def choose_phase(name)
      choose "klass_new_semester_klass_phase_#{SemesterKlass::PHASE_MAP.key(name)}"
    end

    def pick_teacher(name)
      fill_in "教师", with: name
      within("[data-search-select-target='results']") { click_button name }
    end
end
