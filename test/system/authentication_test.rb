require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  test "未登录访问后台会跳转到登录页" do
    visit root_path

    assert_current_path new_session_path
    assert_text "欢迎回来"
  end

  test "用账号密码登录后进入学员管理首页" do
    sign_in

    assert_text "学员管理"
  end

  test "密码错误时回到登录页并给出提示" do
    visit new_session_path
    fill_in "用户名", with: "user1"
    fill_in "密码", with: "wrong-password"
    click_button "登录"

    assert_current_path new_session_path
    assert_text "登录失败"
  end

  test "登录后可从用户菜单登出" do
    sign_in

    find(".dropdown-end [role=button]").click
    click_button "注销登录"

    assert_current_path new_session_path
    visit root_path
    assert_current_path new_session_path
  end
end
