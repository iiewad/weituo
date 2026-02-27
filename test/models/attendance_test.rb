require "test_helper"

class AttendanceTest < ActiveSupport::TestCase
  # before_create :check_course_started
  test "create attendance" do
    course = semester_klasses(:sk_1).courses.first
    attendance = course.attendances.new(
      klass_student_id: klass_students(:ks_1).id
    )
    assert attendance.valid?
    assert attendance.status == "normal"
  end

  test "mark absent" do
    ks = klass_students(:ks_1)
    course = semester_klasses(:sk_1).courses.first
    course.start!
    attendance = course.attendances.find_by(klass_student_id: ks.id)
    attendance.mark_absent!
    assert_equal "absent", attendance.status
    assert attendance.mark_at["absent_at"].present?
    attendance.mark_filled!
    assert_equal "filled", attendance.status
    assert attendance.mark_at["filled_at"].present?
  end
end