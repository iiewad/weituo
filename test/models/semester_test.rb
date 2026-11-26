require "test_helper"

class SemesterTest < ActiveSupport::TestCase
  test "current returns the flagged semester" do
    assert_equal semesters(:semester_current), Semester.current(schools(:school_1).id)
  end

  test "current and history when no semester is flagged" do
    Semester.update_all(current: false)

    assert_nil Semester.current(schools(:school_1).id)
    assert_empty Semester.history(schools(:school_1).id).to_a
  end

  test "history" do
    history_semester = Semester.create!(
      name: "临时",
      school_id: schools(:school_1).id,
      seq: semesters(:semester_previous).seq - 1
    )
    assert_equal [ semesters(:semester_previous), history_semester ], Semester.history(schools(:school_1).id)
  end

  test "related_previous_semester" do
    school = schools(:school_1)
    assert_equal semesters(:semester_previous), semesters(:semester_current).related_previous_semester
  end

  test "related_history_semesters" do
    school = schools(:school_1)
    assert_equal [ semesters(:semester_previous) ], semesters(:semester_current).related_history_semesters
  end

  test "related_next_semester" do
    school = schools(:school_1)
    assert_equal semesters(:semester_current), semesters(:semester_previous).related_next_semester
  end

  test "related semesters follow seq order" do
    current = semesters(:semester_current)
    overlapping = Semester.create!(school: schools(:school_1), name: "重叠学期", seq: 4)
    gap = Semester.create!(school: schools(:school_1), name: "空档学期", seq: 5)

    assert_equal semesters(:semester_next), current.related_next_semester
    assert_equal overlapping, semesters(:semester_next).related_next_semester
    assert_equal gap, overlapping.related_next_semester
    assert_equal overlapping, gap.related_previous_semester
    assert_equal [ overlapping, semesters(:semester_next), current, semesters(:semester_previous) ],
      gap.related_history_semesters.to_a
  end
end
