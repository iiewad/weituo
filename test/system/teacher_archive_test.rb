require "application_system_test_case"

class TeacherArchiveTest < ApplicationSystemTestCase
  test "教师可以存档并在已存档中恢复" do
    sign_in
    teacher = teachers(:math_teacher_1)
    visit admin_teachers_path

    within(find("tr", text: teacher.name)) do
      accept_confirm(/确定将 #{teacher.name} 存档/) { click_button "存档" }
    end

    assert_text "#{teacher.name} 已存档"
    assert teacher.reload.archived?
    assert_no_selector "tr", text: teacher.name

    select "已存档", from: "teacher_status"
    click_button "查找"
    assert_selector "tr", text: /#{teacher.name}/

    within(find("tr", text: teacher.name)) { click_button "恢复" }
    assert_text "已恢复"
    assert_not teacher.reload.archived?
  end
end
