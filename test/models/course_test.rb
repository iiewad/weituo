require "test_helper"

class CourseTest < ActiveSupport::TestCase
  test "fixtures init" do
    assert_equal 16, courses.count
  end

  test "course start" do
    course = courses(:sk_1_course_1)
    course.start!
    assert_equal true, course.started?
  end

  test "start creates an attendance for every enrolled student" do
    course = courses(:sk_1_course_1)

    assert_difference -> { course.attendances.count }, 1 do
      course.start!
    end
    assert_equal "normal", course.attendances.find_by!(klass_student_id: klass_students(:ks_1).id).status
    assert_equal Date.today, course.reload.start_date
  end

  test "start is idempotent" do
    course = courses(:sk_1_course_1)
    course.start!

    assert_no_difference -> { course.attendances.count } do
      course.start!
    end
  end
end
