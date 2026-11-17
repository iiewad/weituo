require "application_system_test_case"

class UsersTest < ApplicationSystemTestCase
  test "创建用户时按所选校区过滤可授权年级，并保存授权" do
    sign_in
    visit admin_users_path
    assert_text "用户管理"

    within(find("#drawer-user-new", visible: :all).ancestor(".drawer-end")) do
      find("label[for='drawer-user-new']").click

      within(".drawer-side") do
        fill_in "用户名", with: "新用户甲"
        fill_in "密码", with: "password"
        click_button "添加校区"

        within(all(".nested-fields").last) do
          select "校1 · 区1", from: "校区"
          # 校1 未开设九年级，选中校区后该年级应被禁用
          assert find("input[value='9']", visible: :all).disabled?

          check "七年级"
          select "管理员", from: "角色"
        end

        click_button "创建用户"
      end
    end

    assert_text "用户创建成功"
    row = find("tr", text: "新用户甲")
    within(row) do
      assert_text "区1"
      assert_text "管理员"
      assert_text "七年级"
    end
  end
end
