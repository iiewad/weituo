require "test_helper"

class KlassTest < ActiveSupport::TestCase
  # 同年级同班型唯一
  test "klass genre seq uniqueness" do
    klass = Klass.new(
      campuse_id: 1,
      subject_id: 1,
      genre: "TG",
      seq: 1,
      teacher_id: 1,
    )
    assert_not klass.valid?
    assert_equal "班级信息已存在，不可重复", klass.errors[:seq].first
  end
end
