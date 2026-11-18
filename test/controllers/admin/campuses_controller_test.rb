require "test_helper"

class Admin::CampusesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "switch thread campuse selects an authorized campus" do
    other = Campuse.create!(name: "第二校区", school: schools(:school_1))
    UserCampuse.create!(user: users(:one), campuse: other, role: "admin")

    get switch_thread_campuse_admin_school_campuse_path(schools(:school_1), other), headers: { "HTTP_REFERER" => root_path }

    assert_redirected_to root_path
    assert_equal other.id, session[:current_campuse_id]
  end

  test "cannot switch to a campus the user is not authorized for" do
    other = Campuse.create!(name: "第二校区", school: schools(:school_1))

    get switch_thread_campuse_admin_school_campuse_path(schools(:school_1), other), headers: { "HTTP_REFERER" => root_path }

    assert_response :not_found
  end

  test "update" do
    put admin_school_campuse_path(schools(:school_1), campuses(:campuse_1)), params: { campuse: { name: "新校区" } }
    assert_redirected_to admin_schools_path
    assert_equal "新校区", campuses(:campuse_1).reload.name
  end

  test "managers cannot update campuses" do
    sign_in_as users(:two)

    put admin_school_campuse_path(schools(:school_1), campuses(:campuse_1)), params: { campuse: { name: "越权改名" } }

    assert_redirected_to root_path
    assert_match "超级管理员", flash[:alert]
    assert_equal "区1", campuses(:campuse_1).reload.name
  end
end
