require "test_helper"

class AttendanceTest < ActiveSupport::TestCase
  # before_create :check_course_started
  test "create attendance" do
    course = semester_klasses(:sk_1).courses.first
    attendance = course.attendances.new(
      student_id: students(:student_7_1).id
    )
    assert attendance.valid?
    assert attendance.status == "normal"
  end
end
