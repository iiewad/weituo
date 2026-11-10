require "test_helper"

class SemesterKlassTest < ActiveSupport::TestCase
  test "should add students by text" do
    # 学员不存在不会被添加
    sk = semester_klasses(:sk_math_1)
    text = "未录入学员"
    sk.add_students_by_text(text)
    assert_nil sk.students.find_by(name: "未录入学员")
    # 年级不符合不会被添加
    text = "8_学生1"
    sk.add_students_by_text(text)
    assert_nil sk.students.find_by(name: "8_学生1")
    # 正常添加
    text = "7_学生2"
    sk.add_students_by_text(text)
    assert_equal 1, sk.students.where(name: "7_学生2").count
    # 正常添加, 已开课程考勤默认 normal
    course = sk.courses.find_by(seq: 1)
    course.start!
    text = "7_学生3"
    sk.add_students_by_text(text)
    assert_equal 1, sk.students.where(name: "7_学生3").count
    assert_equal "normal", course.attendances.find_by(klass_student_id: sk.klass_students.find_by(student_id: sk.students.find_by(name: "7_学生3").id).id).status
    # 插班情况
    text = "7_学生4 4+"
    sk.add_students_by_text(text)
    assert_equal 1, sk.students.where(name: "7_学生4").count
    # 插班课程之前的考勤应该标记为 absent
    sk.courses.where("seq < ?", 4).each do |course|
      assert_equal "absent", course.attendances.find_by(klass_student_id: sk.klass_students.find_by(student_id: sk.students.find_by(name: "7_学生4").id).id).status
    end
    # 插班课程之后的考勤应该标记为 normal
    sk.courses.where("seq >= ? AND start_date IS NOT NULL", 4).each do |course|
      assert_equal "normal", course.attendances.find_by(klass_student_id: sk.klass_students.find_by(student_id: sk.students.find_by(name: "7_学生4").id).id).status
    end
  end

  test "reserve rate" do
    sk = semester_klasses(:sk_math_1)
    (1..10).each do |i|
      students("student_7_#{i}").join_klass(sk)
    end
    sk2 = semester_klasses(:sk_math_2)
    (1..2).each do |i|
      students("student_7_#{i}").join_klass(sk2)
    end
    sk3 = semester_klasses(:sk_math_3)
    (5..6).each do |i|
      students("student_7_#{i}").join_klass(sk3)
    end

    assert_equal 0.4, sk.reserve_rate
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

  test "ended when every course has a start date" do
    sk = semester_klasses(:sk_math_1)
    assert_not sk.ended?

    sk.courses.update_all(start_date: Date.today)
    assert sk.ended?
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

  test "students text lists enrolled names" do
    assert_equal "7_学生1", semester_klasses(:sk_math_1).students_text
  end

  test "new rate treats all students as new when there is no history semester" do
    assert_equal 1.0, semester_klasses(:sk_math_1).new_rate
  end

  test "expand rate is zero when there is no previous semester" do
    assert_equal 0.0, semester_klasses(:sk_math_1).expand_rate
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

  test "ransackable attributes and associations are declared" do
    assert_includes SemesterKlass.ransackable_attributes, "grade_id"
    assert_includes SemesterKlass.ransackable_associations, "courses"
    assert_includes SemesterKlass.ransackable_associations, "campuse"
  end
end
