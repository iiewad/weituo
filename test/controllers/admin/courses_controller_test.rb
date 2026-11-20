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

  test "cannot start a later course before earlier ones" do
    sk = semester_klasses(:sk_math_1)
    course = sk.courses.find_by!(seq: 2)

    put start_admin_semester_klass_course_path(sk, course)

    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "请先开第 1 课", flash[:alert]
    assert_not course.reload.started?
  end

  test "cannot start a class from another campus" do
    other_campuse = Campuse.create!(name: "其他校区", school: schools(:school_1))
    sk = SemesterKlass.create!(
      campuse: other_campuse, semester: semesters(:semester_current),
      grade: grades(:grade_7), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      genre: "TG", seq: 9, times: 1
    )
    course = sk.courses.find_by!(seq: 1)

    put start_admin_semester_klass_course_path(sk, course)

    assert_response :not_found
  end
end
