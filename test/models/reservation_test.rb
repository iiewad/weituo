require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  def build(attributes = {})
    Reservation.new(
      student: students(:student_7_1), semester: semesters(:semester_next), subject: subjects(:math),
      grade: grades(:grade_8), teacher: teachers(:math_teacher_1), genre: "JY", **attributes
    )
  end

  test "one reservation per student, semester and subject" do
    build.save!

    duplicate = build(grade: grades(:grade_7))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:student_id], "该学员已预留该学期同科目"

    assert build(subject: subjects(:eng), teacher: teachers(:eng_teacher_1)).valid?
  end

  test "teacher is optional until a class is generated" do
    reservation = build(teacher: nil, source_semester_klass: semester_klasses(:sk_math_1))

    assert reservation.valid?

    reservation.save!
    assert_equal semesters(:semester_previous), reservation.source_semester
    assert_nil build.source_semester
  end

  test "rejects an unknown genre" do
    reservation = build(genre: "XX")

    assert_not reservation.valid?
    assert_includes reservation.errors.attribute_names, :genre
  end

  test "pending until a class is generated" do
    reservation = build
    reservation.save!
    assert Reservation.pending.exists?(reservation.id)

    reservation.update!(semester_klass: semester_klasses(:sk_math_1))
    assert_not Reservation.pending.exists?(reservation.id)  end

  test "generated class follows the source class phase" do
    assert_equal 1, build.phase

    second_phase = SemesterKlass.create!(
      campuse: campuses(:campuse_1), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      seq: 5, genre: "TG", grade: grades(:grade_7), semester: semesters(:semester_current), times: 1, phase: 2
    )
    assert_equal 2, build(source_semester_klass: second_phase).phase
  end

  test "deleting the semester removes its reservations" do
    build.save!

    assert_difference -> { Reservation.count }, -1 do
      semesters(:semester_next).destroy!
    end
  end
end
