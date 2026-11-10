require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "new is public" do
    get new_password_path
    assert_response :success
  end
end
