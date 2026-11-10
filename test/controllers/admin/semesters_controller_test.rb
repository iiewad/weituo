require "test_helper"

class Admin::SemestersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "switch thread semester" do
    get switch_thread_semester_admin_school_semester_path(schools(:school_1), semesters(:semester_next)), headers: { "HTTP_REFERER" => root_path }
    assert_redirected_to root_path
  end
end
