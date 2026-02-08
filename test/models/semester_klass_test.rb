require "test_helper"

class SemesterKlassTest < ActiveSupport::TestCase
  test "fixtures init" do
    assert_equal 1, SemesterKlass.count
    assert_equal "7数提1", SemesterKlass.first.name
    assert_equal 1, semester_klasses(:sk_1).klass_students.count
    assert_equal 16, semester_klasses(:sk_1).courses.count
  end
end
