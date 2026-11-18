require "test_helper"

class Admin::GuidesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "show renders the guide content and table of contents" do
    get admin_guide_path

    assert_response :success
    assert_select "h1", text: "操作指南"
    assert_select "aside a[href^='#guide-section-']", minimum: 10
    assert_select "article.guide-content h2", text: /登录与全局操作/
    assert_select "a[title='操作指南'][aria-current='page']"
  end
end
