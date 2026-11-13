require "test_helper"

class TeacherTest < ActiveSupport::TestCase
  test "name with subject" do
    assert_equal "数学 张", teachers(:math_teacher_1).name_with_subject
  end

  test "requires a name" do
    teacher = Teacher.new(subject: subjects(:math), campuse: campuses(:campuse_1))
    assert_not teacher.valid?
    assert teacher.errors[:name].any?
  end

  test "ransackable attributes expose searchable fields only" do
    assert_includes Teacher.ransackable_attributes, "name"
    assert_includes Teacher.ransackable_attributes, "subject_id"
    assert_includes Teacher.ransackable_associations, "subject"
  end

  test "add by text imports only known subjects" do
    text = "数学,新老师,13800000000\n不存在的科目,坏老师,138"

    assert_difference -> { Teacher.count }, 1 do
      Teacher.add_by_text(campuses(:campuse_1).id, text)
    end
    assert Teacher.find_by(name: "新老师", subject_id: subjects(:math).id)
  end

  test "add by text is idempotent" do
    text = "英语,王老师,139"
    Teacher.add_by_text(campuses(:campuse_1).id, text)
    assert_no_difference -> { Teacher.count } do
      Teacher.add_by_text(campuses(:campuse_1).id, text)
    end
  end
end
