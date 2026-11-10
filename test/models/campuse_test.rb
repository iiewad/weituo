require "test_helper"

class CampuseTest < ActiveSupport::TestCase
  test "belongs to a school and owns students and teachers" do
    campuse = campuses(:campuse_1)
    assert_equal schools(:school_1), campuse.school
    assert_includes campuse.students, students(:student_7_1)
    assert_includes campuse.teachers, teachers(:math_teacher_1)
  end
end
