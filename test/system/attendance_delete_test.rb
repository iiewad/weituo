require "application_system_test_case"

class AttendanceDeleteTest < ApplicationSystemTestCase
  test "移出确认弹窗里取消后不会移出学员" do
    sign_in
    visit admin_semester_klass_path(semester_klasses(:sk_math_2))

    klass_student = klass_students(:ks_2)

    find("input[data-attendance-select-target='rowCheckbox'][value='#{students(:student_7_1).id}']").check
    click_button "移出"

    within("dialog#remove-modal") do
      assert_text "历史考勤会保留"
      find("button[aria-label='关闭']").click
    end

    assert_current_path admin_semester_klass_path(semester_klasses(:sk_math_2))
    assert KlassStudent.exists?(klass_student.id), "取消确认后不应删除报名记录"
    assert_nil klass_student.reload.archived_at, "取消确认后不应移出学员"
  end
end
