require "test_helper"

class Admin::ReferralsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index shows referral summary, ranking and records" do
    get admin_referrals_path

    assert_response :success
    assert_select "h1", text: "推荐统计"
    assert_includes response.body, "共 4 条推荐关系"
    assert_includes response.body, "推荐排行"
    assert_includes response.body, "9_学生1"
    assert_includes response.body, "7_学生1"
    assert_includes response.body, "3 人"
  end

  test "index filters referrals by referrer grade" do
    get admin_referrals_path(grade_id: grades(:grade_7).id)
    assert_response :success
    assert_includes response.body, "暂无推荐记录"
    assert_select "select[name='grade_id'] option[selected][value='#{grades(:grade_7).id}']"
  end
end
