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
end
