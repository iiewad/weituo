require "test_helper"

class Admin::StudentsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index" do
    get admin_students_path
    assert_response :success
  end

  %w[in_class not_in_class out_class].each do |filter|
    test "index with #{filter} filter" do
      get admin_students_path(filter: filter)
      assert_response :success
    end
  end

  test "create" do
    assert_difference -> { Student.count }, 1 do
      post admin_students_path, params: { student: { name: "新学员", campuse_id: campuses(:campuse_1).id, grade_id: grades(:grade_7).id } }
    end
    assert_redirected_to admin_students_path
  end

  test "create always uses the current campus" do
    other = Campuse.create!(name: "第二校区", school: schools(:school_1))

    assert_difference -> { Student.count }, 1 do
      post admin_students_path, params: { student: { name: "新学员", grade_id: grades(:grade_7).id, campuse_id: other.id } }
    end

    assert_equal campuses(:campuse_1).id, Student.find_by!(name: "新学员").campuse_id
  end

  test "update" do
    student = students(:student_7_1)
    put admin_student_path(student), params: { student: { name: "改名" } }
    assert_redirected_to admin_students_path
    assert_equal "改名", student.reload.name
  end
end
