require "application_system_test_case"

class GuideWizardTest < ApplicationSystemTestCase
  test "首次进入首页自动弹出使用指引并可逐步浏览" do
    users(:one).update!(guide_completed_at: nil)
    sign_in

    assert_selector "dialog#guide-wizard[open]"
    within("dialog#guide-wizard") do
      assert_text "确认校区与学期"
      assert_text "第 1 / 6 步"

      click_button "下一步"
      assert_text "配置年级科目与课次"
      assert_text "第 2 / 6 步"

      click_button "上一步"
      assert_text "确认校区与学期"
      assert_button "开始使用", visible: :all
    end
  end

  test "完成后不再自动弹出，使用指引入口可重新打开" do
    users(:one).update!(guide_completed_at: nil)
    sign_in

    within("dialog#guide-wizard") do
      5.times { click_button "下一步" }
      click_button "开始使用"
    end

    assert_no_selector "dialog#guide-wizard[open]"
    Timeout.timeout(5) { sleep 0.1 until users(:one).reload.guide_completed_at }

    first(:link, "使用指引").click
    assert_selector "dialog#guide-wizard[open]"
  end
end
