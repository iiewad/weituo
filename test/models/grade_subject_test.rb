require "test_helper"

class GradeSubjectTest < ActiveSupport::TestCase
  test "name combines grade and subject" do
    assert_equal "七年级 数学", grade_subjects(:one).name
  end

  test "belongs to a semester and validates times" do
    grade_subject = grade_subjects(:one)

    assert_equal semesters(:semester_current), grade_subject.semester
    assert_equal 16, grade_subject.times

    grade_subject.times = 0
    assert_not grade_subject.valid?
    assert grade_subject.errors[:times].any?
  end

  test "rejects a semester from another school" do
    other_school = School.create!(name: "其他学校")
    other_semester = other_school.semesters.create!(
      name: "其他学期", seq: 1
    )
    grade_subject = GradeSubject.new(
      school: schools(:school_1), semester: other_semester,
      grade: grades(:grade_7), subject: subjects(:math)
    )

    assert_not grade_subject.valid?
    assert_includes grade_subject.errors[:semester_id], "与学校不一致"
  end
end
