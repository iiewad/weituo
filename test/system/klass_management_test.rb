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

    find("label[for='drawer-reserve']").click

    within("form[action='#{reserve_admin_semester_klass_path(sk)}']") do
      select "精英班", from: "班型"
      click_button "确认预留"
    end

    assert_text "已预留 1 名学员"
    # 预留只登记，不直接建班
    assert_equal 0, SemesterKlass.where(semester: semesters(:semester_next)).count

    visit admin_reservations_path
    assert_text "待分班"
    accept_confirm(/生成班级/) { click_button "生成班级" }

    assert_text "已生成班级"
    target = SemesterKlass.where(semester: semesters(:semester_next)).order(:id).last
    assert_equal grades(:grade_8), target.grade
    assert_equal grades(:grade_7), students(:student_7_1).reload.grade
    assert target.klass_students.exists?(student_id: students(:student_7_1).id)
  end

  test "开班搜索不到学员时可以快速添加并直接选中" do
    sign_in
    visit admin_semester_klasses_path

    find("label[for='drawer-klass-new']").click
    drawer = find("#drawer-klass-new", visible: :all).ancestor(".drawer-end")

    within(drawer) do
      select "七年级", from: "年级"
      fill_in "搜索学员姓名", with: "新学员"
      assert_text "没有匹配的学员"
      click_button "快速添加学员"
      assert_selector "[data-student-multiselect-target='selected']", text: "新学员", wait: 5
      select "张", from: "教师"
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
      select "七年级", from: "年级"
      choose "粘贴名单"
      fill_in "粘贴名单（每行：姓名,入班课次）", with: "7_学生2,2\n7_学生3\n新粘同学,1\n新粘同学,1"
      select "张", from: "教师"
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
      select "第二阶段", from: "阶段"
      select "提高班", from: "班型"
      select "七年级", from: "年级"
      select "张", from: "教师"
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
      select "提高班", from: "班型"
      select "七年级", from: "年级"
      select "张", from: "教师"
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
    assert_text "开第 4 课"
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
      select "七年级", from: "年级"
      select "张", from: "教师"
      assert_field "课次", with: "16"

      select "八年级", from: "年级"
      select "王", from: "教师"
      assert_field "课次", with: "12"

      select "七年级", from: "年级"
      assert_field "课次", with: ""
      select "张", from: "教师"
      assert_field "课次", with: "16"
    end
  end

  test "在班级管理页开班并生成课次" do
    sign_in
    visit admin_semester_klasses_path

    find("label[for='drawer-klass-new']").click
    drawer = find("#drawer-klass-new", visible: :all).ancestor(".drawer-end")

    within(drawer) do
      select "精英班", from: "班型"
      select "七年级", from: "年级"
      select "张", from: "教师"
      assert_field "课次", with: "16"
      fill_in "课次", with: "3"
      click_button "开班"
    end

    assert_text "班级创建成功"
    assert_text "一期7数精1"
    assert_equal 3, SemesterKlass.order(:id).last.courses.count
  end
end
