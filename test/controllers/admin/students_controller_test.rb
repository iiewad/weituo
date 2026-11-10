require "test_helper"

class Admin::StudentsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index" do
    get admin_students_path
    assert_response :success
  end

  test "index with in class filter" do
    get admin_students_path(filter: "in_class")
    assert_response :success
  end

  test "create" do
    assert_difference -> { Student.count }, 1 do
      post admin_students_path, params: { student: { name: "新学员", campuse_id: campuses(:campuse_1).id, grade_id: grades(:grade_7).id } }
    end
    assert_redirected_to admin_students_path
  end

  test "update" do
    student = students(:student_7_1)
    put admin_student_path(student), params: { student: { name: "改名" } }
    assert_redirected_to admin_students_path
    assert_equal "改名", student.reload.name
  end
end
