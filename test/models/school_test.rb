require "test_helper"

class SchoolTest < ActiveSupport::TestCase
  test "a school only owns campuses" do
    school = schools(:school_1)
    assert_includes school.campuses, campuses(:campuse_1)
    assert_not school.respond_to?(:semesters)
    assert_not school.respond_to?(:current_semester)
    assert_not school.respond_to?(:grades)
    assert_not school.respond_to?(:subjects)
  end

  test "requires a name" do
    school = School.new(name: "")
    assert_not school.valid?
    assert school.errors[:name].any?
  end
end
