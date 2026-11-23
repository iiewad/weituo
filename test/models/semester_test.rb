require "test_helper"

class SemesterTest < ActiveSupport::TestCase
  test "current" do
    school = schools(:school_1)
    assert_equal semesters(:semester_current), Semester.current(school.id)
  end

  test "current and history when no semester covers today" do
    Semester.update_all(start_date: 1.year.ago.to_date, end_date: 11.months.ago.to_date)

    assert_nil Semester.current(schools(:school_1).id)
    assert_empty Semester.history(schools(:school_1).id).to_a
  end

  test "history" do
    history_semester = Semester.create(
        name: "临时",
        school_id: schools(:school_1).id,
        seq: semesters(:semester_previous).seq - 1,
        start_date: semesters(:semester_current).start_date - 1.year,
        end_date: semesters(:semester_current).end_date - 1.year,
    )
    school = schools(:school_1)
    assert_equal [ semesters(:semester_previous), history_semester ], Semester.history(school.id)
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

  test "related semesters follow seq even when date ranges overlap or leave gaps" do
    current = semesters(:semester_current)
    # 日期与上图重叠的后续学期（seq 更大），旧实现会因 start_date < end_date 找不到
    overlapping = Semester.create!(
      school: schools(:school_1), name: "重叠学期", seq: 4,
      start_date: current.end_date - 10.days, end_date: current.end_date + 1.month
    )
    # 与上一学期之间留空档（seq 5）
    gap = Semester.create!(
      school: schools(:school_1), name: "空档学期", seq: 5,
      start_date: overlapping.end_date + 3.months, end_date: overlapping.end_date + 4.months
    )

    assert_equal semesters(:semester_next), current.related_next_semester
    assert_equal overlapping, semesters(:semester_next).related_next_semester
    assert_equal gap, overlapping.related_next_semester
    assert_equal overlapping, gap.related_previous_semester
    assert_equal [ overlapping, semesters(:semester_next), current, semesters(:semester_previous) ],
      gap.related_history_semesters.to_a
  end
end
