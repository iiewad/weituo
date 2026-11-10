require "test_helper"

class Admin::SchoolsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index" do
    get admin_schools_path
    assert_response :success
  end

  test "update" do
    put admin_school_path(schools(:school_1)), params: { school: { name: "新学校" } }
    assert_redirected_to admin_schools_path
    assert_equal "新学校", schools(:school_1).reload.name
  end
end
