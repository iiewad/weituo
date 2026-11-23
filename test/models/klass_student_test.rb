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

  test "reinstate removes the enrollment created by a transfer" do
    source = klass_students(:ks_1)
    target_sk = semester_klasses(:sk_eng_1)
    target = KlassStudent.create!(semester_klass: target_sk, student: students(:student_7_1), status: "in")
    course = courses(:sk_1_course_1)
    course.start!
    attendance = course.attendances.find_by!(klass_student_id: source.id)
    attendance.update!(
      status: "transfer",
      mark_at: { "transfer_at" => Time.current.iso8601, "transfer_target_klass_id" => target_sk.id }
    )
    source.update!(status: :transfer)

    source.reinstate!

    assert_equal "in", source.reload.status
    assert_equal "normal", attendance.reload.status
    assert target.reload.archived_at.present?
  end
end
