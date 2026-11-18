require "application_system_test_case"

class StudentsTest < ApplicationSystemTestCase
  test "勾选学员后可以批量升年级" do
    sign_in
    visit admin_students_path

    student = students(:student_7_1)
    check "student-select-#{student.id}"
    assert_button "批量升年级", disabled: false

    accept_confirm(/确定将选中的学员/) { click_button "批量升年级" }

    assert_text "已为 1 名学员升年级"
    assert_equal grades(:grade_8), student.reload.grade
  end

  test "学员详情抽屉展示基本信息与历史班级" do
    sign_in
    visit admin_students_path

    student = students(:student_7_1)
    within("#student-row-#{student.id}") { find("label.btn", text: "详情").click }

    drawer = find("#drawer-student-detail-#{student.id}", visible: :all).ancestor(".drawer-end")
    within(drawer) do
      assert_text "历史班级"
      assert_text semester_klasses(:sk_math_1).name
      assert_text semester_klasses(:sk_math_2).name
      assert_text "在班"
      assert_text "当前学期"
      assert_text "监护人"
      assert_text guardians(:g_1).phone
    end
  end
end
