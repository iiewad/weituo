require "test_helper"

class Admin::KlassStudentsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "archives an enrollment instead of deleting its attendance" do
    sk = semester_klasses(:sk_math_2)
    ks = klass_students(:ks_2)
    attendance = Attendance.create!(course: courses(:sk_2_course_1), klass_student: ks, status: "normal")

    assert_no_difference -> { KlassStudent.unscoped.count } do
      delete admin_semester_klass_klass_student_path(sk, ks)
    end

    assert_redirected_to admin_semester_klass_path(sk)
    assert ks.reload.archived_at.present?
    assert Attendance.exists?(attendance.id)
    assert_not_includes sk.klass_students.reload, ks
  end

  test "reinstate restores a quit student" do
    sk = semester_klasses(:sk_math_2)
    ks = klass_students(:ks_2)
    course = courses(:sk_2_course_1)
    course.update!(start_date: Date.current)
    attendance = course.attendances.create!(klass_student: ks, status: "normal")
    attendance.mark_quit!

    put reinstate_admin_semester_klass_klass_student_path(sk, ks)

    assert_redirected_to admin_semester_klass_path(sk)
    assert_equal "in", ks.reload.status
    assert_equal "normal", attendance.reload.status
  end

  test "restores an archived enrollment" do
    sk = semester_klasses(:sk_math_2)
    ks = klass_students(:ks_2)
    ks.archive!

    put restore_admin_semester_klass_klass_student_path(sk, ks)

    assert_redirected_to admin_semester_klass_path(sk)
    assert_nil ks.reload.archived_at
    assert_includes sk.klass_students.reload, ks
  end
end
