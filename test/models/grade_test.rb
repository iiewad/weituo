require "test_helper"

class GradeTest < ActiveSupport::TestCase
  test "subjects come through grade subjects" do
    assert_equal [ "数学" ], grades(:grade_7).subjects.pluck(:name)
  end

  test "semester klasses are linked by grade" do
    assert_includes grades(:grade_7).semester_klasses, semester_klasses(:sk_math_1)
  end
end
