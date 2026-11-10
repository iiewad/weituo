require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index" do
    get admin_users_path
    assert_response :success
  end

  test "edit" do
    get edit_admin_user_path(users(:one))
    assert_response :success
  end

  test "create" do
    assert_difference -> { User.count }, 1 do
      post admin_users_path, params: { user: { name: "new_user", password: "password" } }
    end
    assert_redirected_to admin_users_path
  end
end
