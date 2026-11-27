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

  test "班级预留报表展示汇总卡与表格" do
    visit statement_admin_semester_klasses_path

    assert_text "班级预留报表"
    assert_text "统计班级"
    assert_text "平均预留率"
    assert_selector "table"
  end

  test "年级报表展示口径与分学期表格" do
    visit admin_grade_reports_path

    assert_text "年级报表"
    assert_text "口径"
    assert_text semesters(:semester_current).name
    assert_selector "table"
    assert_selector "label.drawer-button", text: "详情"
  end

  test "顶栏切换学期后班级列表随之更新" do
    visit admin_semester_klasses_path
    assert_text semester_klasses(:sk_math_2).name
    assert_no_text semester_klasses(:sk_math_1).name

    find(".dropdown-end [role=button]").click
    click_link semesters(:semester_previous).name
    # 链接由 Turbo 异步导航，等切换请求落地再进入列表页，避免竞态。
    assert_text "学期切换成功"

    visit admin_semester_klasses_path
    assert_text semester_klasses(:sk_math_1).name
    assert_no_text semester_klasses(:sk_math_2).name
  end

  test "点击班级卡片进入考勤详情" do
    visit admin_semester_klasses_path

    click_link semester_klasses(:sk_math_2).name

    assert_current_path admin_semester_klass_path(semester_klasses(:sk_math_2))
    assert_text "在班"
    assert_text "课次"
  end
end
