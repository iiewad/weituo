require "test_helper"

class KlassStudentTest < ActiveSupport::TestCase
  test "starts in and transitions between out and transfer" do
    ks = klass_students(:ks_1)
    assert_equal "in", ks.status

    ks.mark_out!
    assert_equal "out", ks.status

    ks.mark_transfer!
    assert_equal "transfer", ks.status

    ks.mark_out!
    assert_equal "out", ks.status
  end

  test "reinstate restores the leave attendance and the enrollment" do
    ks = klass_students(:ks_1)
    course = courses(:sk_1_course_1)
    course.start!
    attendance = course.attendances.find_by!(klass_student_id: ks.id)
    attendance.mark_quit!
    assert_equal "out", ks.reload.status

    ks.reinstate!

    assert_equal "in", ks.reload.status
    assert_equal "normal", attendance.reload.status
  end

  test "archived enrollments are excluded from active scopes and associations" do
    ks = klass_students(:ks_2)
    sk = ks.semester_klass
    ks.archive!

    assert_not_includes sk.klass_students, ks
    assert_not_includes sk.students, ks.student
    assert_includes sk.all_klass_students, ks
    assert_includes sk.archived_klass_students, ks
    assert_not_includes KlassStudent.active, ks
    assert_includes KlassStudent.archived, ks

    # 历史考勤仍能取到已移出的报名记录
    attendance = sk.courses.find_by!(seq: 1).attendances.create!(klass_student: ks)
    assert_equal ks, attendance.reload.klass_student
  end

  test "reinstate leaves a transferred target class and transfer rows untouched" do
    source = klass_students(:ks_1)
    target_sk = semester_klasses(:sk_eng_1)
    target = KlassStudent.create!(semester_klass: target_sk, student: students(:student_7_1), status: "in")
    course = courses(:sk_1_course_1)
    course.start!
    attendance = course.attendances.find_by!(klass_student_id: source.id)
    attendance.update!(
      status: "transfer",
      transfer_target_klass_id: target_sk.id
    )
    source.update!(status: :transfer)

    source.reinstate!

    assert_equal "in", source.reload.status
    assert_equal "transfer", attendance.reload.status
    assert_equal target_sk.id, attendance.transfer_target_klass_id
    assert_nil target.reload.archived_at
  end

  test "reinstate only restores quit rows and keeps earlier transfer history" do
    ks = klass_students(:ks_1)
    first = courses(:sk_1_course_1)
    second = courses(:sk_1_course_2)
    [ first, second ].each(&:start!)
    first_row = first.attendances.find_by!(klass_student_id: ks.id)
    first_row.update!(status: "transfer")
    second_row = second.attendances.find_by!(klass_student_id: ks.id)
    second_row.update!(status: "quit")
    ks.update!(status: :out)

    ks.reinstate!

    assert_equal "transfer", first_row.reload.status
    assert_equal "normal", second_row.reload.status
    assert_equal "in", ks.reload.status
  end
end
