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

  test "archive hides the teacher from the active scope and restore brings it back" do
    teacher = teachers(:math_teacher_1)

    assert_not teacher.archived?
    teacher.archive!
    assert teacher.reload.archived?
    assert_includes Teacher.archived, teacher
    assert_not_includes Teacher.active, teacher

    teacher.restore!
    assert_not teacher.reload.archived?
    assert_includes Teacher.active, teacher
  end

  test "add by text imports only known subjects" do
    text = "数学,新老师,13800000000\n不存在的科目,坏老师,138"

    assert_difference -> { Teacher.count }, 1 do
      Teacher.add_by_text(campuses(:campuse_1).id, text)
    end
    assert Teacher.find_by(name: "新老师", subject_id: subjects(:math).id)
  end

  test "rejects a subject not offered by the school" do
    subject = Subject.create!(name: "物理", code: "PHY")
    teacher = Teacher.new(name: "物理老师", subject:, campuse: campuses(:campuse_1))

    assert_not teacher.valid?
    assert_includes teacher.errors[:subject_id], "未在该学校开设"
  end

  test "add by text supports tabs, headers and duplicate skipping" do
    text = [ "科目\t姓名\t电话", "数学\t表格老师\t138", "数学\t表格老师\t139", "英语\t表格老师\t137" ].join("\n")

    created = skipped = nil
    assert_difference -> { Teacher.count }, 2 do
      created, skipped = Teacher.add_by_text(campuses(:campuse_1).id, text)
    end

    assert_equal 2, created
    assert_equal 1, skipped
    assert Teacher.exists?(name: "表格老师", subject: subjects(:math), phone: "138")
    assert_not Teacher.exists?(name: "表格老师", subject: subjects(:math), phone: "139")
  end

  test "add by text is idempotent" do
    text = "英语,王老师,139"
    Teacher.add_by_text(campuses(:campuse_1).id, text)
    assert_no_difference -> { Teacher.count } do
      Teacher.add_by_text(campuses(:campuse_1).id, text)
    end
  end
end
