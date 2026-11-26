require "test_helper"

class Admin::SchoolsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index" do
    get admin_schools_path
    assert_response :success
  end

  test "managers cannot manage school settings" do
    sign_in_as users(:two)

    get admin_schools_path

    assert_redirected_to root_path
    assert_match "超级管理员", flash[:alert]
  end

  test "update" do
    put admin_school_path(schools(:school_1)), params: { school: { name: "新学校" } }
    assert_redirected_to admin_schools_path
    assert_equal "新学校", schools(:school_1).reload.name
  end

  test "update adds a nested campus" do
    assert_difference -> { Campuse.count }, 1 do
      put admin_school_path(schools(:school_1)), params: {
        school: { campuses_attributes: { "0" => { name: "新校区" } } }
      }
    end
    assert_redirected_to admin_schools_path
    assert_equal schools(:school_1).id, Campuse.find_by!(name: "新校区").school_id
  end

  test "a new campus is granted to the current admin so it shows in the switcher" do
    assert_difference -> { UserCampuse.count }, 1 do
      put admin_school_path(schools(:school_1)), params: {
        school: { campuses_attributes: { "0" => { name: "新校区" } } }
      }
    end

    campuse = Campuse.find_by!(name: "新校区")
    user_campuse = users(:one).user_campuses.find_by!(campuse: campuse)
    assert_equal "admin", user_campuse.role
    assert_equal Grade.order(:level).ids, user_campuse.grade_ids.sort
    assert_match "新校区", flash[:notice]

    get admin_schools_path
    assert_select "a[href*='/campuses/#{campuse.id}/switch_thread_campuse']", text: "新校区"
  end

  test "editing an existing campus does not add new grants" do
    campuse = campuses(:campuse_1)

    assert_no_difference -> { UserCampuse.count } do
      put admin_school_path(schools(:school_1)), params: {
        school: { campuses_attributes: { "0" => { id: campuse.id, name: "改名校区" } } }
      }
    end

    assert_equal "改名校区", campuse.reload.name
  end

  test "update adds a nested semester" do
    assert_difference -> { Semester.count }, 1 do
      put admin_school_path(schools(:school_1)), params: {
        school: { semesters_attributes: { "0" => {
          name: "新学期", seq: 9
        } } }
      }
    end
    assert_redirected_to admin_schools_path
  end

  test "update sets the chosen current semester" do
    school = schools(:school_1)

    put admin_school_path(school), params: { school: { current_semester_id: semesters(:semester_next).id } }

    assert_redirected_to admin_schools_path
    assert_equal semesters(:semester_next), school.reload.current_semester
    assert_not semesters(:semester_current).reload.current?
  end

  test "update with a blank name fails without raising" do
    assert_no_difference -> { School.count } do
      put admin_school_path(schools(:school_1)), params: { school: { name: "" } }
    end
    assert_redirected_to admin_schools_path
    assert_match "失败", flash[:alert]
    assert_equal "校1", schools(:school_1).reload.name
  end

  test "schools routes are limited to index and update" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/admin/schools/new", method: :get)
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/admin/schools/1", method: :delete)
    end
  end
end
