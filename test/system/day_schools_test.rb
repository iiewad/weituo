require "application_system_test_case"

class DaySchoolsTest < ApplicationSystemTestCase
  test "学员抽屉里可以快速添加日校并自动选中" do
    sign_in
    visit admin_students_path

    find("label[for='drawer-student-new']").click
    within("form[action='#{admin_students_path}'][method='post']") do
      click_button "快速添加"
    end

    within("dialog#quick-day-school-modal") do
      fill_in "日校名称", with: "快捷日校"
      click_button "保存并填入"
    end

    assert_no_selector "dialog#quick-day-school-modal[open]"
    within("form[action='#{admin_students_path}'][method='post']") do
      assert_equal "快捷日校", find("select[name='student[day_school_id]'] option:checked").text
    end
    assert DaySchool.exists?(name: "快捷日校", campuse: campuses(:campuse_1))
  end

  test "超管可以新增并删除日校" do
    sign_in
    visit admin_day_schools_path

    find("label[for='drawer-day-school-new']").click
    within("form[action='#{admin_day_schools_path}']") do
      fill_in "日校名称", with: "系统测试日校"
      click_button "添加日校"
    end

    assert_text "日校已添加"
    assert_text "系统测试日校"

    day_school = DaySchool.find_by!(name: "系统测试日校")
    accept_confirm(/确定删除/) do
      within("tr", text: "系统测试日校") { find("button[title='删除']").click }
    end

    assert_text "日校已删除"
    assert_not DaySchool.exists?(day_school.id)
  end
end
