require "test_helper"

class Admin::TeachersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index sets thread context through AdminController" do
    get admin_teachers_path

    assert_response :success
    assert_equal campuses(:campuse_1).id, Thread.current[:campuse].id
  end

  test "create" do
    assert_difference -> { Teacher.count }, 1 do
      post admin_teachers_path, params: { teacher: { name: "新老师", phone: "123", campuse_id: campuses(:campuse_1).id, subject_id: subjects(:math).id } }
    end
    assert_redirected_to admin_teachers_path
  end

  test "update" do
    teacher = teachers(:math_teacher_1)
    put admin_teacher_path(teacher), params: { teacher: { name: "改名" } }
    assert_redirected_to admin_teachers_path
    assert_equal "改名", teacher.reload.name
  end
end
