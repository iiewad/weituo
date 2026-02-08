require "test_helper"

class CourseTest < ActiveSupport::TestCase
  test "fixtures init" do
    assert_equal 16, courses.count
  end
end
