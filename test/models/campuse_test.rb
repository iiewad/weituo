require "test_helper"

class CampuseTest < ActiveSupport::TestCase
  test "belongs to a school and owns students and teachers" do
    campuse = campuses(:campuse_1)
    assert_equal schools(:school_1), campuse.school
    assert_includes campuse.students, students(:student_7_1)
    assert_includes campuse.teachers, teachers(:math_teacher_1)
  end

  test "owns semesters, grades, subjects and grade_subjects" do
    campuse = campuses(:campuse_1)
    assert_includes campuse.semesters, semesters(:semester_current)
    assert_includes campuse.grades, grades(:grade_7)
    assert_includes campuse.subjects, subjects(:math)
    assert_includes campuse.grade_subjects, grade_subjects(:one)
  end

  test "current and history semesters" do
    campuse = campuses(:campuse_1)
    assert_equal semesters(:semester_current), campuse.current_semester
    assert_equal [ semesters(:semester_previous) ], campuse.history_semesters.to_a
  end

  test "destroy cascades all resources under the campuse" do
    campuse = campuses(:campuse_1)
    student = students(:student_7_1)
    Reservation.create!(
      student: student,
      semester: semesters(:semester_current),
      subject: subjects(:math),
      grade: grades(:grade_7),
      genre: SemesterKlass::GENRE_MAP.values.first
    )

    student_ids = campuse.students.ids
    klass_ids = campuse.semester_klasses.ids

    assert_difference -> { Campuse.count } => -1,
      -> { Student.count } => -student_ids.size,
      -> { Reservation.count } => -1,
      -> { SemesterKlass.count } => -klass_ids.size,
      -> { KlassStudent.count } => -KlassStudent.count,
      -> { Course.count } => -Course.count,
      -> { Attendance.count } => -Attendance.count,
      -> { Teacher.count } => -campuse.teachers.count,
      -> { DaySchool.count } => -campuse.day_schools.count,
      -> { UserCampuse.count } => -campuse.user_campuses.count,
      -> { Semester.count } => -campuse.semesters.count,
      -> { GradeSubject.count } => -campuse.grade_subjects.count,
      -> { Grade.count } => -campuse.grades.count,
      -> { Subject.count } => -campuse.subjects.count do
      campuse.destroy!
    end
  end
end
