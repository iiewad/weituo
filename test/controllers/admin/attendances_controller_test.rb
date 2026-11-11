require "test_helper"

class Admin::AttendancesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  %w[absent personal_leave sick_leave quit transfer].each do |status|
    test "mark #{status}" do
      attendance = prepared_attendance

      mark(attendance, status)

      assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
      assert_equal status, attendance.reload.status
    end
  end

  test "mark filled after an absence" do
    attendance = prepared_attendance
    attendance.mark_absent!

    mark(attendance, "filled")

    assert_equal "filled", attendance.reload.status
  end

  test "mark rejoin after quitting" do
    attendance = prepared_attendance
    attendance.mark_quit!

    mark(attendance, "rejoin")

    assert_equal "normal", attendance.reload.status
  end

  test "mark quit cascades to later courses and the enrollment" do
    attendance = prepared_attendance

    mark(attendance, "quit")

    assert_equal "out", klass_students(:ks_1).reload.status
    later = semester_klasses(:sk_math_1).courses.find_by!(seq: 2)
    assert_equal "quit", later.attendances.find_by!(klass_student_id: klass_students(:ks_1).id).status
  end

  test "mark ignores an unknown status" do
    attendance = prepared_attendance

    assert_no_changes -> { attendance.reload.status } do
      mark(attendance, "bogus")
    end

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_equal "normal", attendance.reload.status
  end

  private
    def prepared_attendance
      course = semester_klasses(:sk_math_1).courses.find_by!(seq: 1)
      course.start!
      course.attendances.find_by!(klass_student_id: klass_students(:ks_1).id)
    end

    def mark(attendance, status)
      put mark_admin_semester_klass_course_attendance_path(
        attendance.course.semester_klass, attendance.course, attendance, status: status
      )
    end
end
