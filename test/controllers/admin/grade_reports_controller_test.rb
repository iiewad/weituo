require "test_helper"

class Admin::GradeReportsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index renders semester grouped grade rows" do
    get admin_grade_reports_path

    assert_response :success
    assert_select "h1", text: "年级报表"
    assert_select "a[href='#{export_admin_grade_reports_path}']", text: /导出报表/
    # fixtures 报名都在七年级，学期分组含当前学期
    assert_select "span.badge", text: semesters(:semester_current).name
  end

  test "index filters by semester" do
    get admin_grade_reports_path(semester_id: semesters(:semester_current).id)

    assert_response :success
    assert_select "a[href='#{export_admin_grade_reports_path(semester_id: semesters(:semester_current).id)}']", text: /导出报表/
    assert_select "span.badge", text: semesters(:semester_previous).name, count: 0
  end

  test "index only shows allowed grades for managers" do
    sign_in_as users(:two)

    get admin_grade_reports_path

    assert_response :success
    assert_select "span.badge", text: "七年级", count: 0
  end

  test "export streams xlsx" do
    get export_admin_grade_reports_path

    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
  end
end
