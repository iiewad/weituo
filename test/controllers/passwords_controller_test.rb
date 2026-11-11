require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "new is public" do
    get new_password_path
    assert_response :success
  end

  test "create redirects to login with a notice" do
    post passwords_path, params: { email_address: "whoever@example.com" }

    assert_redirected_to new_session_path
    assert_match "管理员", flash[:notice]
  end

  test "edit rejects an invalid token" do
    get edit_password_path("invalid-token")

    assert_redirected_to new_password_path
    assert_match "无效", flash[:alert]
  end

  test "update rejects an invalid token" do
    put password_path("invalid-token"), params: { password: "newpassword", password_confirmation: "newpassword" }

    assert_redirected_to new_password_path
    assert_match "无效", flash[:alert]
  end
end
