require "test_helper"

class Admin::TeachersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index sets thread context through AdminController" do
    get admin_teachers_path

    assert_response :success
    assert_equal campuses(:campuse_1).id, Thread.current[:campuse].id
  end

  test "index only lists teachers in the current campus" do
    other = Campuse.create!(name: "第二校区", school: schools(:school_1))
    Teacher.create!(name: "别区老师", subject: subjects(:math), campuse: other)

    get admin_teachers_path

    assert_response :success
    assert_select "tbody tr", count: 4
    assert_no_match "别区老师", response.body
  end

  test "index filters by name" do
    get admin_teachers_path, params: { q: { name_cont: "张" } }

    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody tr span.font-medium", text: "张"
  end

  test "index filters by subject" do
    get admin_teachers_path, params: { q: { subject_id_eq: subjects(:math).id } }

    assert_response :success
    assert_select "tbody tr", count: 2
  end

  test "create" do
    assert_difference -> { Teacher.count }, 1 do
      post admin_teachers_path, params: { teacher: { name: "新老师", phone: "123", subject_id: subjects(:math).id } }
    end
    assert_redirected_to admin_teachers_path
  end

  test "create always uses the current campus regardless of submitted campuse_id" do
    other = Campuse.create!(name: "第二校区", school: schools(:school_1))

    post admin_teachers_path, params: { teacher: {
      name: "越权老师", phone: "123", subject_id: subjects(:math).id, campuse_id: other.id
    } }

    assert_equal campuses(:campuse_1).id, Teacher.find_by!(name: "越权老师").campuse_id
  end

  test "create with a blank name fails without raising" do
    assert_no_difference -> { Teacher.count } do
      post admin_teachers_path, params: { teacher: { name: "", subject_id: subjects(:math).id } }
    end
    assert_redirected_to admin_teachers_path
    assert_match "失败", flash[:alert]
  end

  test "update" do
    teacher = teachers(:math_teacher_1)
    put admin_teacher_path(teacher), params: { teacher: { name: "改名" } }
    assert_redirected_to admin_teachers_path
    assert_equal "改名", teacher.reload.name
  end

  test "update with a blank name fails without raising" do
    teacher = teachers(:math_teacher_1)
    put admin_teacher_path(teacher), params: { teacher: { name: "" } }
    assert_redirected_to admin_teachers_path
    assert_match "失败", flash[:alert]
    assert_equal "张", teacher.reload.name
  end

  test "update cannot modify a teacher from another campus" do
    other = Campuse.create!(name: "第二校区", school: schools(:school_1))
    outsider = Teacher.create!(name: "别区老师", subject: subjects(:math), campuse: other)

    put admin_teacher_path(outsider), params: { teacher: { name: "被篡改" } }

    assert_response :not_found
    assert_equal "别区老师", outsider.reload.name
  end

  test "teacher routes are limited to index, create and update" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/admin/teachers/new", method: :get)
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/admin/teachers/1", method: :delete)
    end
  end
end
