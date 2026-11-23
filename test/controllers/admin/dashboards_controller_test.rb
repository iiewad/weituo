require "test_helper"

class Admin::DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index renders the overview" do
    get root_path

    assert_response :success
    assert_select "h1", text: "首页概览"
    assert_select "h2", text: "快捷操作"
    assert_select "h2", text: "最近班级"
    assert_select "h2", text: "最近学员"
    assert_select "a[href='#{admin_students_path}']"
    assert_select "a[href='#{admin_semester_klasses_path}']"
    assert_select "a[href='#{statement_admin_semester_klasses_path}']"
  end

  test "shows the guide wizard on the first visit" do
    users(:one).update!(guide_completed_at: nil)

    get root_path

    assert_response :success
    assert_select "dialog#guide-wizard[data-guide-wizard-auto-open-value='true']"
    assert_select "dialog#guide-wizard [data-guide-wizard-target='step']", minimum: 5
    assert_select "dialog#guide-wizard", text: /确认校区与学期/
    assert_select "dialog#guide-wizard a[href='#{admin_grade_subjects_path}']", text: "年级科目管理"
    assert_select "dialog#guide-wizard [data-guide-wizard-target='progress']"
  end

  test "does not auto open the guide once completed" do
    get root_path

    assert_select "dialog#guide-wizard[data-guide-wizard-auto-open-value='false']"
  end

  test "reopens the guide with the query flag" do
    get root_path(guide: 1)

    assert_select "dialog#guide-wizard[data-guide-wizard-auto-open-value='true']"
  end

  test "managers do not see the admin-only curriculum step" do
    sign_in_as users(:two)
    users(:two).update!(guide_completed_at: nil)

    get root_path

    assert_response :success
    assert_select "dialog#guide-wizard", text: /准备教师与学员/
    assert_select "dialog#guide-wizard", text: /配置年级科目与课次/, count: 0
  end

  test "recent classes link to the current semester class" do
    get root_path

    assert_response :success
    assert_select "a[href='#{admin_semester_klass_path(semester_klasses(:sk_math_2))}']"
  end
end
