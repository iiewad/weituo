require "test_helper"

class GradeSubjectTest < ActiveSupport::TestCase
  test "name combines grade and subject" do
    assert_equal "七年级 数学", grade_subjects(:one).name
  end
end
