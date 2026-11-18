require "application_system_test_case"

class AttendanceDeleteTest < ApplicationSystemTestCase
  test "删除学员前会弹出警告确认" do
    sign_in
    visit admin_semester_klass_path(semester_klasses(:sk_math_2))

    klass_student = klass_students(:ks_2)

    dismiss_confirm(/删除后该学员的考勤记录会一并移除/) do
      find("button[title='删除']").click
    end

    assert_current_path admin_semester_klass_path(semester_klasses(:sk_math_2))
    assert KlassStudent.exists?(klass_student.id), "取消确认后不应删除学员"
  end
end
