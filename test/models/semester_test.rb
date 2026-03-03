require "test_helper"

class SemesterTest < ActiveSupport::TestCase
  test "current" do
    school = schools(:school_1)
    assert_equal semesters(:semester_current), Semester.current(school.id)
  end

  test "history" do
    history_semester = Semester.create(
        name: "临时",
        school_id: schools(:school_1).id,
        seq: semesters(:semester_current).seq - 1,
        start_date: semesters(:semester_current).start_date - 1.year,
        end_date: semesters(:semester_current).end_date - 1.year,
    )
    school = schools(:school_1)
    assert_equal [semesters(:semester_previous), history_semester], Semester.history(school.id)
  end

  test "related_previous_semester" do
    school = schools(:school_1)
    assert_equal semesters(:semester_previous), semesters(:semester_current).related_previous_semester
  end

  test "related_history_semesters" do
    school = schools(:school_1)
    assert_equal [semesters(:semester_previous)], semesters(:semester_current).related_history_semesters
  end

  test "related_next_semester" do
    school = schools(:school_1)
    assert_equal semesters(:semester_current), semesters(:semester_previous).related_next_semester
  end
end
