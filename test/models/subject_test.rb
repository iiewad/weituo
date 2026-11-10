require "test_helper"

class SubjectTest < ActiveSupport::TestCase
  test "has teachers" do
    assert_includes subjects(:math).teachers, teachers(:math_teacher_1)
  end
end
