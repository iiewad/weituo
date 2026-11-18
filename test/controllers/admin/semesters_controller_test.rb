require "test_helper"

class Admin::SemestersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "switch thread semester" do
    get switch_thread_semester_admin_school_semester_path(schools(:school_1), semesters(:semester_next)), headers: { "HTTP_REFERER" => root_path }
    assert_redirected_to root_path
    assert_equal semesters(:semester_next).id, session[:current_semester_id]
  end

  test "cannot switch to a semester from another school" do
    other_school = School.create!(name: "其他学校")
    other_semester = other_school.semesters.create!(
      name: "其他学期", start_date: Date.current, end_date: Date.current + 1.month, seq: 1
    )

    get switch_thread_semester_admin_school_semester_path(schools(:school_1), other_semester)

    assert_response :not_found
  end
end
