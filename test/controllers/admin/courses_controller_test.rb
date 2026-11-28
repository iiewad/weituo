require "test_helper"

class Admin::CoursesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "start creates attendances for enrolled students" do
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.find_by!(seq: 1)

    assert_difference -> { course.attendances.count }, 1 do
      put start_admin_semester_klass_course_path(sk, course)
    end
    assert_redirected_to admin_semester_klass_path(sk)
    assert course.reload.started?
  end

  test "starting an already started course reports it instead of success" do
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.find_by!(seq: 1)
    course.start!

    assert_no_difference -> { course.attendances.count } do
      put start_admin_semester_klass_course_path(sk, course)
    end

    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "已开课，无需重复操作", flash[:alert]
    assert_nil flash[:notice]
  end

  test "start_through opens all courses up to the chosen lesson" do
    sk = semester_klasses(:sk_math_2)

    assert_difference -> { Attendance.count }, 3 do
      put start_through_admin_semester_klass_courses_path(sk), params: { through_seq: 3 }
    end

    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "已开第 1–3 课", flash[:notice]
    assert_equal 3, sk.courses.where.not(start_date: nil).count
    assert sk.courses.find_by!(seq: 3).started?
  end

  test "start_through skips courses that are already open" do
    sk = semester_klasses(:sk_math_2)
    sk.courses.find_by!(seq: 1).start!

    assert_difference -> { Attendance.count }, 2 do
      put start_through_admin_semester_klass_courses_path(sk), params: { through_seq: 3 }
    end

    assert_redirected_to admin_semester_klass_path(sk)
    assert_equal 3, sk.courses.where.not(start_date: nil).count
  end

  test "start_through accumulates custom start dates by interval" do
    sk = semester_klasses(:sk_math_2)

    put start_through_admin_semester_klass_courses_path(sk),
      params: { through_seq: 3, start_date: "2026-03-01", interval_days: 5 }

    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "已开第 1–3 课（03-01 ~ 03-11）", flash[:notice]
    assert_equal [ Date.new(2026, 3, 1), Date.new(2026, 3, 6), Date.new(2026, 3, 11) ],
      sk.courses.where(seq: 1..3).order(:seq).pluck(:start_date)
  end

  test "start_through defaults to today with a weekly interval" do
    sk = semester_klasses(:sk_math_2)

    put start_through_admin_semester_klass_courses_path(sk), params: { through_seq: 2 }

    assert_redirected_to admin_semester_klass_path(sk)
    assert_equal [ Date.today, Date.today + 7 ],
      sk.courses.where(seq: 1..2).order(:seq).pluck(:start_date)
  end

  test "start_through falls back to defaults for blank or invalid input" do
    sk = semester_klasses(:sk_math_2)

    put start_through_admin_semester_klass_courses_path(sk),
      params: { through_seq: 2, start_date: "不是日期", interval_days: "" }

    assert_redirected_to admin_semester_klass_path(sk)
    assert_equal [ Date.today, Date.today + 7 ],
      sk.courses.where(seq: 1..2).order(:seq).pluck(:start_date)
  end

  test "start_through clamps the interval into range" do
    sk = semester_klasses(:sk_math_2)

    put start_through_admin_semester_klass_courses_path(sk),
      params: { through_seq: 2, start_date: "2026-03-01", interval_days: 9999 }

    assert_redirected_to admin_semester_klass_path(sk)
    assert_equal [ Date.new(2026, 3, 1), Date.new(2026, 3, 1) + 365 ],
      sk.courses.where(seq: 1..2).order(:seq).pluck(:start_date)
  end

  test "start_through rejects a lesson that is already open" do
    sk = semester_klasses(:sk_math_2)
    sk.courses.find_by!(seq: 1).start!

    assert_no_difference -> { Attendance.count } do
      put start_through_admin_semester_klass_courses_path(sk), params: { through_seq: 1 }
    end

    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "已开课或不存在", flash[:alert]
  end

  test "cannot start a later course before earlier ones" do
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.find_by!(seq: 2)

    put start_admin_semester_klass_course_path(sk, course)

    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "请先开第 1 课", flash[:alert]
    assert_not course.reload.started?
  end

  test "cannot start a class from another campus" do
    other_campuse = Campuse.create!(name: "其他校区", school: schools(:school_1))
    other_semester = other_campuse.semesters.create!(name: "其他学期", seq: 1)
    sk = SemesterKlass.create!(
      campuse: other_campuse, semester: other_semester,
      grade: grades(:grade_7), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      genre: "TG", seq: 9, times: 1
    )
    course = sk.courses.find_by!(seq: 1)

    put start_admin_semester_klass_course_path(sk, course)

    assert_response :not_found
  end
end
