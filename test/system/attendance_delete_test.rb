require "application_system_test_case"

class AttendanceDeleteTest < ApplicationSystemTestCase
  test "删除学员前会弹出警告确认" do
    sign_in
    visit admin_semester_klass_path(semester_klasses(:sk_math_2))

    klass_student = klass_students(:ks_2)

    dismiss_confirm(/历史考勤会保留/) do
      find("button[title='移出班级']").click
    end

    assert_current_path admin_semester_klass_path(semester_klasses(:sk_math_2))
    assert KlassStudent.exists?(klass_student.id), "取消确认后不应移出学员"
  end
end
