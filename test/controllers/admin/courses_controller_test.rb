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

  test "insert students adds selected students from the chosen course" do
    sk = semester_klasses(:sk_math_1)
    course = sk.courses.find_by!(seq: 4)

    assert_difference -> { sk.klass_students.count }, 1 do
      post insert_students_admin_semester_klass_course_path(sk, course), params: { student_ids: [ students(:student_7_2).id ] }
    end
    assert_redirected_to admin_semester_klass_path(sk)

    student = students(:student_7_2)
    ks = sk.klass_students.find_by!(student_id: student.id)
    assert_equal "absent", sk.courses.find_by!(seq: 1).attendances.find_by!(klass_student_id: ks.id).status
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

  test "insert students requires a selection" do
    sk = semester_klasses(:sk_math_1)
    course = sk.courses.find_by!(seq: 4)

    assert_no_difference -> { sk.klass_students.count } do
      post insert_students_admin_semester_klass_course_path(sk, course), params: { student_ids: [ "" ] }
    end

    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "请先选择", flash[:alert]
  end

  test "insert students skips students already in the class" do
    sk = semester_klasses(:sk_math_1)
    course = sk.courses.find_by!(seq: 4)

    assert_no_difference -> { sk.klass_students.count } do
      post insert_students_admin_semester_klass_course_path(sk, course), params: { student_ids: [ students(:student_7_1).id ] }
    end

    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "已在班级", flash[:alert]
  end
end
