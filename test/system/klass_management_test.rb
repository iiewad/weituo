require "application_system_test_case"

class KlassManagementTest < ApplicationSystemTestCase
  test "从班级菜单切换到同科目的其他班级" do
    sign_in
    visit admin_semester_klass_path(semester_klasses(:sk_math_2))

    within(".menu") { click_link semester_klasses(:sk_math_3).name }

    assert_current_path admin_semester_klass_path(semester_klasses(:sk_math_3))
    assert_selector "a.menu-active", text: semester_klasses(:sk_math_3).name
  end

  test "在班级管理页开班并生成课次" do
    sign_in
    visit admin_semester_klasses_path

    find("label[for='drawer-klass-new']").click
    drawer = find("#drawer-klass-new", visible: :all).ancestor(".drawer-end")

    within(drawer) do
      select "精英班", from: "班型"
      fill_in "班级序号", with: "9"
      select "七年级", from: "年级"
      select "张", from: "教师"
      fill_in "课次", with: "3"

      find("[data-student-remote-multiselect-target='input']").set("7_学生2")
      find("[data-student-remote-multiselect-target='results'] button", text: "7_学生2").click

      click_button "开班"
    end

    assert_text "班级创建成功"
    assert_text "7数精9"
    klass = SemesterKlass.order(:id).last
    assert_equal 3, klass.courses.count
    assert klass.klass_students.exists?(student: students(:student_7_2))
  end
end
