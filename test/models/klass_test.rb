require "test_helper"

class KlassTest < ActiveSupport::TestCase
  test "fixtures init" do
    assert_equal 1, Klass.count
    assert_equal "数提1", Klass.first.name
    assert_equal 1, klasses(:klass_1).semester_klasses.count
  end
  test "klass name" do
    klass = Klass.new(
      campuse: campuses(:campuse_1),
      subject: subjects(:math),
      genre: "TG",
      seq: 1,
      teacher_id: teachers(:math_teacher_1).id
    )
    assert_equal "数提1", klass.name
  end

  # 同年级同班型唯一
  test "klass genre seq uniqueness" do
    klass = Klass.new(
      campuse_id: campuses(:campuse_1).id,
      subject_id: subjects(:math).id,
      genre: "TG",
      seq: 1,
      teacher_id: teachers(:math_teacher_1).id
    )
    assert_not klass.valid?
    assert_equal "班级信息已存在，不可重复", klass.errors[:seq].first
  end
end
