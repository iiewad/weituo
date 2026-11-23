require "application_system_test_case"

class DaySchoolsTest < ApplicationSystemTestCase
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
