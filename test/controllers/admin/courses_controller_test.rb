require "test_helper"

class Admin::CoursesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "start creates attendances for enrolled students" do
    sk = semester_klasses(:sk_math_1)
    course = sk.courses.find_by!(seq: 1)

    assert_difference -> { course.attendances.count }, 1 do
      put start_admin_semester_klass_course_path(sk, course)
    end
    assert_redirected_to admin_semester_klass_path(sk)
    assert course.reload.started?
  end

  test "insert students adds a student from text" do
    sk = semester_klasses(:sk_math_1)
    course = sk.courses.find_by!(seq: 4)

    assert_difference -> { sk.klass_students.count }, 1 do
      post insert_students_admin_semester_klass_course_path(sk, course), params: { course: { students_text: "7_学生2" } }
    end
    assert_redirected_to admin_semester_klass_path(sk)
  end
end
