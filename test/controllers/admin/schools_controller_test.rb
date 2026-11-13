require "test_helper"

class Admin::SchoolsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index" do
    get admin_schools_path
    assert_response :success
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

  test "update destroys a nested grade subject" do
    gs = grade_subjects(:two)
    assert_difference -> { GradeSubject.count }, -1 do
      put admin_school_path(schools(:school_1)), params: {
        school: { grade_subjects_attributes: { "0" => { id: gs.id, _destroy: "true" } } }
      }
    end
    assert_redirected_to admin_schools_path
    assert_not GradeSubject.exists?(gs.id)
  end

  test "update adds a nested semester" do
    assert_difference -> { Semester.count }, 1 do
      put admin_school_path(schools(:school_1)), params: {
        school: { semesters_attributes: { "0" => {
          name: "新学期", start_date: Date.current, end_date: Date.current + 3.months, seq: 9
        } } }
      }
    end
    assert_redirected_to admin_schools_path
  end

  test "update adds a nested user campus with grade ids" do
    assert_difference -> { UserCampuse.count }, 1 do
      put admin_school_path(schools(:school_1)), params: {
        school: { user_campuses_attributes: { "0" => {
          user_id: users(:two).id, campuse_id: campuses(:campuse_1).id,
          role: "manager", grade_ids: [ "7", "8" ]
        } } }
      }
    end
    assert_redirected_to admin_schools_path
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
