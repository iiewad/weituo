require "test_helper"

class Admin::SemesterKlassesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "index" do
    get admin_semester_klasses_path
    assert_response :success
  end

  test "statement" do
    get statement_admin_semester_klasses_path
    assert_response :success
  end

  test "show" do
    get admin_semester_klass_path(semester_klasses(:sk_math_2))
    assert_response :success
  end

  test "copy" do
    get copy_admin_semester_klasses_path
    assert_response :success
  end

  test "create" do
    assert_difference -> { SemesterKlass.count }, 1 do
      post admin_semester_klasses_path, params: { semester_klass: {
        semester_id: semesters(:semester_current).id,
        grade_id: grades(:grade_7).id,
        teacher_id: teachers(:math_teacher_1).id,
        campuse_id: campuses(:campuse_1).id,
        genre: "JY", seq: 99, times: 3, students_text: ""
      } }
    end
    assert_redirected_to admin_semester_klass_path(SemesterKlass.last)
  end
end
