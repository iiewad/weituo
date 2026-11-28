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

  test "rejects a semester from another campuse" do
    other_campuse = Campuse.create!(name: "其他校区", school: schools(:school_1))
    other_semester = other_campuse.semesters.create!(
      name: "其他学期", seq: 1
    )
    grade_subject = GradeSubject.new(
      campuse: campuses(:campuse_1), semester: other_semester,
      grade: grades(:grade_7), subject: subjects(:math)
    )

    assert_not grade_subject.valid?
    assert_includes grade_subject.errors[:semester_id], "与校区不一致"
  end

  test "rejects a grade or subject from another campuse" do
    other_campuse = Campuse.create!(name: "其他校区", school: schools(:school_1))
    other_grade = other_campuse.grades.create!(name: "七年级", level: 7)
    other_subject = other_campuse.subjects.create!(name: "数学", code: "MATH")
    grade_subject = GradeSubject.new(
      campuse: campuses(:campuse_1), semester: semesters(:semester_current),
      grade: other_grade, subject: other_subject
    )

    assert_not grade_subject.valid?
    assert_includes grade_subject.errors[:grade_id], "与校区不一致"
    assert_includes grade_subject.errors[:subject_id], "与校区不一致"
  end
end
