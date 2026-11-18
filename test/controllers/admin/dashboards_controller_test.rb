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

  test "recent classes link to the current semester class" do
    get root_path

    assert_response :success
    assert_select "a[href='#{admin_semester_klass_path(semester_klasses(:sk_math_2))}']"
  end
end
