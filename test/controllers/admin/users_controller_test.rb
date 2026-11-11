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

  test "update changes the name and password" do
    user = users(:two)

    put admin_user_path(user), params: { user: { name: "改名", password: "newpassword" } }

    assert_redirected_to admin_users_path
    assert_equal "改名", user.reload.name
    assert user.authenticate("newpassword")
  end

  test "create without a password does not create a user" do
    assert_no_difference -> { User.count } do
      post admin_users_path, params: { user: { name: "no_password", password: "" } }
    end

    assert_redirected_to admin_users_path
    assert_match "失败", flash[:alert]
  end
end
