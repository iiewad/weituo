require "application_system_test_case"

class UsersTest < ApplicationSystemTestCase
  test "创建用户时按所选校区过滤可授权年级，并保存授权" do
    # 年级归属校区：再建一个校区和它自己的年级，用于验证切换校区时按 data-campuse-id 过滤
    other = Campuse.create!(name: "区2", school: schools(:school_1))
    other_grade = other.grades.create!(name: "十年级", level: 10)
    UserCampuse.create!(user: users(:one), school: schools(:school_1), campuse: other, role: "admin", grade_ids: [])

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
          # 选中区1后：其它校区的年级被禁用，区1 自己的年级（含九年级）可选
          assert find("input[value='#{other_grade.id}']", visible: :all).disabled?
          assert_not find("input[value='#{grades(:grade_9).id}']", visible: :all).disabled?

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
