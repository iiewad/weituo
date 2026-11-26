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

  test "预留下学期并新建目标班级" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    visit admin_semester_klass_path(sk)

    find("label[for='drawer-reserve']").click

    within("form[action='#{reserve_admin_semester_klass_path(sk)}']") do
      select "精英班", from: "班型"
      fill_in "课次", with: "8"
      click_button "确认预留"
    end

    assert_text "已预留 1 名学员"
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
    assert_text "7数精1"
    assert_equal 3, SemesterKlass.order(:id).last.courses.count
  end
end
