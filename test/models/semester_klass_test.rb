require "test_helper"

class SemesterKlassTest < ActiveSupport::TestCase
  test "join_klass fills absences before the entry course and attendances after it" do
    sk = semester_klasses(:sk_math_1)
    sk.courses.order(:seq).limit(4).each(&:start!)
    student = students(:student_7_2)

    student.join_klass(sk, course_seq: 4)

    ks = sk.klass_students.find_by!(student_id: student.id)
    sk.courses.where("seq < ?", 4).each do |row|
      assert_equal "absent", row.attendances.find_by!(klass_student_id: ks.id).status
    end
    assert_equal "normal", sk.courses.find_by!(seq: 4).attendances.find_by!(klass_student_id: ks.id).status
  end

  test "creates times courses after create" do
    sk = SemesterKlass.create!(
      campuse: campuses(:campuse_1),
      subject: subjects(:math),
      teacher: teachers(:math_teacher_1),
      semester: semesters(:semester_previous),
      grade: grades(:grade_7),
      genre: "JY",
      seq: 99,
      times: 3
    )

    assert_equal 3, sk.courses.count
    assert_equal [ 1, 2, 3 ], sk.courses.order(:seq).pluck(:seq)
  end

  test "increasing times adds the missing courses" do
    sk = semester_klasses(:sk_math_1)
    assert_equal 16, sk.courses.count

    sk.update!(times: 20)

    assert_equal (1..20).to_a, sk.courses.order(:seq).pluck(:seq)
  end

  test "decreasing times removes the extra unstarted courses" do
    sk = semester_klasses(:sk_math_1)

    sk.update!(times: 12)

    assert_equal (1..12).to_a, sk.courses.order(:seq).pluck(:seq)
  end

  test "times cannot drop below the started courses" do
    sk = semester_klasses(:sk_math_1)
    sk.courses.find_by!(seq: 1).start!
    sk.courses.find_by!(seq: 2).start!

    assert_not sk.update(times: 1)
    assert_includes sk.errors[:times], "已有 2 个课次开课，不能小于该值"
    assert_equal 16, sk.reload.times
    assert_equal 16, sk.courses.count
  end

  test "grade cannot change once the class has students" do
    sk = semester_klasses(:sk_math_1)

    assert_not sk.update(grade_id: grades(:grade_8).id)
    assert_includes sk.errors[:grade_id], "班级已有学员，不能修改年级"
    assert_equal grades(:grade_7), sk.reload.grade
  end

  test "grade can change while the class is empty" do
    sk = semester_klasses(:sk_math_3)

    assert sk.update(grade_id: grades(:grade_8).id)
    assert_equal grades(:grade_8), sk.reload.grade
  end

  test "ended when every course has a start date" do
    sk = semester_klasses(:sk_math_1)
    assert_not sk.ended?

    sk.courses.update_all(start_date: Date.today)
    assert sk.ended?
  end

  test "next seq increments and skips numbers containing 4" do
    sk = semester_klasses(:sk_math_1)
    attrs = {
      campuse_id: sk.campuse_id, semester_id: sk.semester_id,
      grade_id: sk.grade_id, subject_id: sk.subject_id, genre: sk.genre
    }

    # 现有 sk_math_1 序号为 1
    assert_equal 2, SemesterKlass.next_seq(**attrs)

    sk.update_column(:seq, 3)
    assert_equal 5, SemesterKlass.next_seq(**attrs)
  end

  test "name is built from grade, subject, genre and seq" do
    assert_equal "7数提1", semester_klasses(:sk_math_1).name
  end

  test "active and inactive students" do
    sk = semester_klasses(:sk_math_1)
    assert_equal [ "7_学生1" ], sk.current_active_students.pluck(:name)
    assert_empty sk.inactive_students

    klass_students(:ks_1).update!(status: "out")

    assert_empty sk.current_active_students
    assert_equal [ "7_学生1" ], sk.inactive_students.pluck(:name)
  end

  test "validates unique class combination within a semester" do
    sk = semester_klasses(:sk_math_1)
    duplicate = SemesterKlass.new(
      campuse: sk.campuse, subject: sk.subject, teacher: sk.teacher,
      semester: sk.semester, grade: sk.grade, genre: sk.genre, seq: sk.seq, times: sk.times
    )

    assert_not duplicate.valid?
    assert duplicate.errors[:semester_id].any?
  end

  test "rejects a subject that differs from the teacher subject" do
    sk = semester_klasses(:sk_math_1)
    sk.subject = subjects(:eng)

    assert_not sk.valid?
    assert_includes sk.errors[:subject_id], "与教师科目不一致"
  end

  test "ransackable attributes and associations are declared" do
    assert_includes SemesterKlass.ransackable_attributes, "grade_id"
    assert_includes SemesterKlass.ransackable_associations, "courses"
    assert_includes SemesterKlass.ransackable_associations, "campuse"
  end
end
