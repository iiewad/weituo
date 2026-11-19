require "application_system_test_case"

class GradeSubjectsTest < ApplicationSystemTestCase
  test "通过矩阵启用年级科目组合" do
    sign_in
    visit admin_grade_subjects_path

    assert_text "年级科目管理"
    find("#combo_9_1").check
    click_button "保存配置"

    assert_text "已更新 1 个年级科目组合"
    assert schools(:school_1).grade_subjects.exists?(grade_id: grades(:grade_9).id, subject_id: subjects(:math).id)
  end

  test "已有班级的组合不可取消" do
    sign_in
    visit admin_grade_subjects_path

    checkbox = find("#combo_7_1", visible: :all)
    assert checkbox.disabled?
    assert_selector "input[type='hidden'][value='7-1']", visible: :all
  end
end
