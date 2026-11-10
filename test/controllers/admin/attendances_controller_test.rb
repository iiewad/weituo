require "test_helper"

class Admin::AttendancesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "mark updates the attendance status" do
    sk = semester_klasses(:sk_math_1)
    course = sk.courses.find_by!(seq: 1)
    course.start!
    attendance = course.attendances.find_by!(klass_student_id: klass_students(:ks_1).id)

    put mark_admin_semester_klass_course_attendance_path(sk, course, attendance, status: "absent")

    assert_redirected_to admin_semester_klass_path(sk)
    assert_equal "absent", attendance.reload.status
  end
end
