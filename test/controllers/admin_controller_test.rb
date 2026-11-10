require "test_helper"

class AdminControllerTest < ActionDispatch::IntegrationTest
  test "index works when no semester covers today" do
    Semester.update_all(start_date: 1.year.ago.to_date, end_date: 11.months.ago.to_date)
    sign_in_as users(:one)

    get root_path

    assert_response :success
  end
end
