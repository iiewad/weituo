require "application_system_test_case"

class StudentSoftDeleteTest < ApplicationSystemTestCase
  test "学员可以软删除并在已删除中恢复" do
    sign_in
    student = students(:student_7_2)
    visit admin_students_path

    within("tr#student-row-#{student.id}") do
      accept_confirm(/确定删除学员/) { click_button "删除" }
    end

    assert_text "#{student.name} 已删除"
    assert student.reload.deleted?
    assert_no_selector "tr#student-row-#{student.id}"

    click_link "已删除"
    assert_selector "tr#student-row-#{student.id}"

    within("tr#student-row-#{student.id}") { click_button "恢复" }
    assert_text "已恢复"
    assert_not student.reload.deleted?
  end
end
