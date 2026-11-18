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

  test "allows students with the same name and distinguishes them by detail" do
    campuse = campuses(:campuse_1)
    first = Student.create!(name: "同名", campuse:, grade: grades(:grade_7), phone: "13800001111")
    second = Student.create!(name: "同名", campuse:, grade: grades(:grade_7), phone: "13800002222")

    assert_equal "尾号1111", first.identity_suffix
    assert_equal "尾号2222", second.identity_suffix
    refute_equal first.identity_detail, second.identity_detail
  end

  test "identity suffix falls back to birthday and id" do
    with_birthday = Student.new(name: "无电话", birthday: Date.new(2010, 5, 1))
    assert_equal "2010-05-01", with_birthday.identity_suffix

    without_contact = Student.create!(name: "无联系方式", campuse: campuses(:campuse_1), grade: grades(:grade_7))
    assert_equal "ID #{without_contact.id}", without_contact.identity_suffix
  end

  test "assigning referrer id creates and clears the referral" do
    student = students(:student_7_5)
    referrer = students(:student_9_2)

    student.update!(referrer_id: referrer.id)
    assert_equal referrer, student.reload.referrer

    student.update!(referrer_id: "")
    assert_nil student.reload.referrer
  end

  test "referrer must belong to the same campus and cannot be the student" do
    student = students(:student_7_5)

    student.update!(referrer_id: student.id)
    assert_nil student.reload.referrer

    student.update!(referrer_id: 0)
    assert_nil student.reload.referrer
  end

  test "import by text maps genders and reports created and skipped rows" do
    text = [
      "导入甲,男,2000-01-01,7,1,2026-01-01,三中,家长甲,13800000001,父亲",
      "导入乙,女,2000-01-01,7,1,2026-01-01,三中",
      "坏日校,男,2000-01-01,7,1,2026-01-01,不存在",
      "未授权年级,男,2000-01-01,9,1,2026-01-01,三中",
      "导入甲,男,2000-01-01,7,1,2026-01-01,三中,家长甲,13800000001,父亲"
    ].join("\n")

    created, skipped = Student.add_by_text(
      campuses(:campuse_1).id,
      text,
      grade_ids: [ grades(:grade_7).id ]
    )

    assert_equal 2, created
    assert_equal 3, skipped
    assert_equal "male", Student.find_by!(name: "导入甲").gender
    assert_equal "female", Student.find_by!(name: "导入乙").gender
    assert_equal grades(:grade_7), Student.find_by!(name: "导入甲").grade
    assert_equal day_schools(:one), Student.find_by!(name: "导入甲").day_school

    guardian = Student.find_by!(name: "导入甲").guardians.sole
    assert_equal "家长甲", guardian.name
    assert_equal "13800000001", guardian.phone
    assert_equal "父亲", guardian.relationship
    assert_empty Student.find_by!(name: "导入乙").guardians
  end

  test "add by text imports only rows with a valid grade and day school" do
    text = "新学员,男,2000-01-01,7,1,2026-01-01,三中\n坏年级,男,2000-01-01,99,1,2026-01-01,三中\n坏日校,男,2000-01-01,7,1,2026-01-01,不存在"

    assert_difference -> { Student.count }, 1 do
      Student.add_by_text(campuses(:campuse_1).id, text)
    end
    assert_equal grades(:grade_7).id, Student.find_by!(name: "新学员").grade_id
  end
end
