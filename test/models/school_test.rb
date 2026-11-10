require "test_helper"

class SchoolTest < ActiveSupport::TestCase
  test "current and history semesters" do
    school = schools(:school_1)
    assert_equal semesters(:semester_current), school.current_semester
    assert_equal [ semesters(:semester_previous) ], school.history_semesters.to_a
  end

  test "grades and subjects come through grade subjects" do
    school = schools(:school_1)
    assert_includes school.grades, grades(:grade_7)
    assert_includes school.subjects, subjects(:math)
  end
end
