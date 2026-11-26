require "application_system_test_case"

class TeacherImportTest < ApplicationSystemTestCase
  test "教师管理可以粘贴名单导入" do
    sign_in
    visit admin_teachers_path

    find("label[for='drawer-teacher-import']").click
    drawer = find("#drawer-teacher-import", visible: :all).ancestor(".drawer-end")

    within(drawer) do
      fill_in "教师名单", with: "数学,导入老师,13800000009\n物理,坏老师,138"
      click_button "开始导入"
    end

    assert_text "新增 1 名教师"
    assert_text "跳过 1 行"
    assert Teacher.exists?(name: "导入老师", subject: subjects(:math))
    assert_not Teacher.exists?(name: "坏老师")
  end
end
