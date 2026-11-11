require "test_helper"

class AdminControllerTest < ActionDispatch::IntegrationTest
  test "index works when no semester covers today" do
    Semester.update_all(start_date: 1.year.ago.to_date, end_date: 11.months.ago.to_date)
    sign_in_as users(:one)

    get root_path

    assert_response :success
  end

  test "admin pages require authentication" do
    [
      root_path,
      admin_students_path,
      admin_semester_klasses_path,
      statement_admin_semester_klasses_path,
      admin_teachers_path,
      admin_users_path,
      admin_schools_path
    ].each do |path|
      get path
      assert_redirected_to new_session_path, "#{path} should require login"
    end
  end

  test "sets the thread current campus, school and semester" do
    sign_in_as users(:one)

    get root_path

    assert_response :success
    assert_equal campuses(:campuse_1).id, Thread.current[:campuse].id
    assert_equal schools(:school_1).id, Thread.current[:school].id
    assert_equal semesters(:semester_current), Thread.current[:semester]
  end

  test "write actions require authentication" do
    post admin_students_path, params: { student: { name: "未登录" } }
    assert_redirected_to new_session_path

    put admin_student_path(students(:student_7_1)), params: { student: { name: "未登录" } }
    assert_redirected_to new_session_path
  end
end
