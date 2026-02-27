require "test_helper"

class SemesterKlassTest < ActiveSupport::TestCase
  test "fixtures init" do
    assert_equal 1, SemesterKlass.count
    assert_equal "7数提1", SemesterKlass.first.name
    assert_equal 1, semester_klasses(:sk_1).klass_students.count
    assert_equal 16, semester_klasses(:sk_1).courses.count
  end

  # # 一个学期不允许有两个klass
  # test "validates :semester_id, uniqueness: { scope: :klass_id }" do
  #   klass = klasses(:klass_1)
  #   sk = klass.semester_klasses.new(
  #     semester_id: semesters(:semester_1).id,
  #     grade_id: grades(:grade_7).id,
  #     times: 10
  #   )
  #   assert_not sk.valid?
  #   assert_equal "该班级已在该学期中存在", sk.errors[:semester_id].first
  # end

  # test "should create courses after create semester klass" do
  #   klass = klasses(:klass_1)
  #   sk = klass.semester_klasses.new(
  #     semester_id: semesters(:semester_2).id,
  #     grade_id: grades(:grade_7).id,
  #     times: 10
  #   )
  #   assert sk.valid?
  #   sk.save!
  #   assert_equal 10, sk.courses.count
  # end

  test "should add students by text" do
    # 学员不存在不会被添加
    sk = semester_klasses(:sk_1)
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
    assert_equal "normal", course.attendances.find_by(student_id: sk.students.find_by(name: "7_学生3").id).status
    # 插班情况
    text = "7_学生4 4+"
    sk.add_students_by_text(text)
    assert_equal 1, sk.students.where(name: "7_学生4").count
    # 插班课程之前的考勤应该标记为 absent
    sk.courses.where("seq < ?", 4).each do |course|
      assert_equal "absent", course.attendances.find_by(student_id: sk.students.find_by(name: "7_学生4").id).status
    end
    # 插班课程之后的考勤应该标记为 normal
    sk.courses.where("seq >= ? AND start_date IS NOT NULL", 4).each do |course|
      assert_equal "normal", course.attendances.find_by(student_id: sk.students.find_by(name: "7_学生4").id).status
    end
  end
end
