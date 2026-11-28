require "test_helper"

class SemesterTest < ActiveSupport::TestCase
  test "current returns the flagged semester" do
    assert_equal semesters(:semester_current), Semester.current(campuses(:campuse_1).id)
  end

  test "current and history when no semester is flagged" do
    Semester.update_all(current: false)

    assert_nil Semester.current(campuses(:campuse_1).id)
    assert_empty Semester.history(campuses(:campuse_1).id).to_a
  end

  test "history" do
    history_semester = Semester.create!(
      name: "临时",
      campuse_id: campuses(:campuse_1).id,
      seq: semesters(:semester_previous).seq - 1
    )
    assert_equal [ semesters(:semester_previous), history_semester ], Semester.history(campuses(:campuse_1).id)
  end

  test "related_previous_semester" do
    assert_equal semesters(:semester_previous), semesters(:semester_current).related_previous_semester
  end

  test "related_history_semesters" do
    assert_equal [ semesters(:semester_previous) ], semesters(:semester_current).related_history_semesters
  end

  test "related_next_semester" do
    assert_equal semesters(:semester_current), semesters(:semester_previous).related_next_semester
  end

  test "related semesters follow seq order" do
    current = semesters(:semester_current)
    overlapping = Semester.create!(campuse: campuses(:campuse_1), name: "重叠学期", seq: 4)
    gap = Semester.create!(campuse: campuses(:campuse_1), name: "空档学期", seq: 5)

    assert_equal semesters(:semester_next), current.related_next_semester
    assert_equal overlapping, semesters(:semester_next).related_next_semester
    assert_equal gap, overlapping.related_next_semester
    assert_equal overlapping, gap.related_previous_semester
    assert_equal [ overlapping, semesters(:semester_next), current, semesters(:semester_previous) ],
      gap.related_history_semesters.to_a
  end

  test "related semesters never cross campuses" do
    other_campuse = Campuse.create!(name: "其他校区", school: schools(:school_1))
    other_next = other_campuse.semesters.create!(name: "其他下学期", seq: 1)

    assert_nil semesters(:semester_next).related_next_semester
    assert_nil other_next.related_next_semester
    assert_equal [ semesters(:semester_previous) ], semesters(:semester_current).related_history_semesters
  end

  test "flagging current unsets the previous flag within the campuse" do
    semesters(:semester_next).update!(current: true)

    assert_equal semesters(:semester_next), Semester.current(campuses(:campuse_1).id)
    assert_not semesters(:semester_current).reload.current
  end

  test "creating the first semester of a campuse makes it current" do
    other_campuse = Campuse.create!(name: "其他校区", school: schools(:school_1))
    semester = other_campuse.semesters.create!(name: "首个学期", seq: 1)

    assert semester.reload.current
    assert_equal semester, Semester.current(other_campuse.id)
  end

  test "destroying the current semester falls back to the smallest seq" do
    semesters(:semester_current).destroy!

    assert_equal semesters(:semester_previous), Semester.current(campuses(:campuse_1).id)
  end
end
