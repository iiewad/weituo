require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  setup { sign_in }

  test "学员列表可按姓名搜索" do
    visit admin_students_path

    fill_in "姓名搜索", with: "7_学生1"
    click_button "查找"

    assert_text "7_学生1"
    assert_no_text "7_学生2"
  end

  test "班级报表展示汇总卡与表格" do
    visit statement_admin_semester_klasses_path

    assert_text "班级报表"
    assert_text "统计班级"
    assert_text "平均新增率"
    assert_selector "table"
  end

  test "顶栏切换学期后班级列表随之更新" do
    visit admin_semester_klasses_path
    open_class_menu
    assert_text semester_klasses(:sk_math_2).name
    assert_no_text semester_klasses(:sk_math_1).name

    find(".dropdown-end [role=button]").click
    click_link semesters(:semester_previous).name
    # 链接由 Turbo 异步导航，等切换请求落地再进入列表页，避免竞态。
    assert_text "学期切换成功"

    visit admin_semester_klasses_path
    open_class_menu
    assert_text semester_klasses(:sk_math_1).name
    assert_no_text semester_klasses(:sk_math_2).name
  end

  private
    # 班级链接藏在折叠的年级 / 科目菜单里，需要像用户一样展开。
    def open_class_menu
      find("summary", text: "七年级").click
      find("summary", text: "数学").click
    end
end
