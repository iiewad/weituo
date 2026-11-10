require "test_helper"

class StudentTest < ActiveSupport::TestCase
  test "ransackable attributes are limited to name and grade" do
    assert_equal [ "name", "grade_id" ], Student.ransackable_attributes
  end

  test "join klass creates enrollment and attendance for started courses" do
    student = students(:student_7_2)
    sk = semester_klasses(:sk_math_1)
    course = sk.courses.find_by!(seq: 1)
    course.start!

    student.join_klass(sk)

    ks = sk.klass_students.find_by!(student_id: student.id)
    assert_equal "normal", course.attendances.find_by!(klass_student_id: ks.id).status
  end

  test "join klass rejects a different grade" do
    sk = semester_klasses(:sk_math_1)
    student = students(:student_8_1)

    assert_nil student.join_klass(sk)
    assert_nil sk.klass_students.find_by(student_id: student.id)
  end

  test "update grade moves to the next level and stops at the top" do
    student = students(:student_7_1)
    student.update_grade
    assert_equal grades(:grade_8).id, student.reload.grade_id

    top = students(:student_9_1)
    top.update_grade
    assert_equal grades(:grade_9).id, top.reload.grade_id
  end

  test "add by text imports only rows with a valid grade and day school" do
    text = "新学员,男,2000-01-01,7,1,2026-01-01,三中\n坏年级,男,2000-01-01,99,1,2026-01-01,三中\n坏日校,男,2000-01-01,7,1,2026-01-01,不存在"

    assert_difference -> { Student.count }, 1 do
      Student.add_by_text(campuses(:campuse_1).id, text)
    end
    assert_equal grades(:grade_7).id, Student.find_by!(name: "新学员").grade_id
  end
end
