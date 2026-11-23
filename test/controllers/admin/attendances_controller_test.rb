require "test_helper"

class Admin::AttendancesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  %w[absent personal_leave sick_leave quit].each do |status|
    test "mark #{status}" do
      attendance = prepared_attendance

      mark(attendance, status)

      assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
      assert_equal status, attendance.reload.status
    end
  end

  test "mark records the operator and timestamp" do
    attendance = prepared_attendance

    mark(attendance, "absent")

    assert_equal users(:one), attendance.reload.marked_by
    assert attendance.created_at.present?
    assert attendance.updated_at.present?
  end

  test "mark filled after an absence" do
    attendance = prepared_attendance
    attendance.mark_absent!

    mark(attendance, "filled")

    assert_equal "filled", attendance.reload.status
  end

  test "mark rejoin after quitting" do
    attendance = prepared_attendance
    attendance.mark_quit!

    mark(attendance, "rejoin")

    assert_equal "normal", attendance.reload.status
  end

  test "mark quit cascades to later started courses and the enrollment" do
    attendance = prepared_attendance
    later = semester_klasses(:sk_math_1).courses.find_by!(seq: 2)
    later.start!

    mark(attendance, "quit")

    assert_equal "out", klass_students(:ks_1).reload.status
    assert_equal "quit", later.attendances.find_by!(klass_student_id: klass_students(:ks_1).id).status
    assert_nil semester_klasses(:sk_math_1).courses.find_by!(seq: 3)
      .attendances.find_by(klass_student_id: klass_students(:ks_1).id)
  end

  test "cannot mark attendance from another campus" do
    other_campuse = Campuse.create!(name: "其他校区", school: schools(:school_1))
    sk = SemesterKlass.create!(
      campuse: other_campuse, semester: semesters(:semester_current),
      grade: grades(:grade_7), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      genre: "TG", seq: 9, times: 1
    )
    ks = KlassStudent.create!(semester_klass: sk, student: students(:student_7_1), status: "in")
    course = sk.courses.find_by!(seq: 1)
    course.start!
    attendance = course.attendances.find_by!(klass_student: ks)

    put mark_admin_semester_klass_course_attendance_path(sk, course, attendance, status: "absent")

    assert_response :not_found
    assert_equal "normal", attendance.reload.status
  end

  test "mark rejects an unknown status" do
    attendance = prepared_attendance

    assert_no_changes -> { attendance.reload.status } do
      mark(attendance, "bogus")
    end

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_equal "未知的考勤状态", flash[:alert]
    assert_nil attendance.reload.marked_by
  end

  test "mark rejects a bare transfer without a target class" do
    attendance = prepared_attendance

    mark(attendance, "transfer")

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_match "转出请在转出抽屉中选择目标班级", flash[:alert]
    assert_equal "normal", attendance.reload.status
    assert_nil attendance.reload.marked_by
    assert_equal "in", klass_students(:ks_1).reload.status
  end

  test "mark reports an invalid transition instead of raising" do
    attendance = prepared_attendance

    mark(attendance, "rejoin")

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_match "无法改为「重新加入」", flash[:alert]
    assert_equal "normal", attendance.reload.status
    assert_nil attendance.reload.marked_by
  end

  test "transfer marks the source and enrolls the student in the target class" do
    attendance = prepared_attendance
    target = semester_klasses(:sk_eng_1)

    put transfer_admin_semester_klass_course_attendance_path(
      attendance.course.semester_klass, attendance.course, attendance,
      target_semester_klass_id: target.id
    )

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_equal "transfer", attendance.reload.status
    assert_equal "transfer", klass_students(:ks_1).reload.status
    assert target.klass_students.exists?(student_id: students(:student_7_1).id)
  end

  test "transfer requires an available target class" do
    attendance = prepared_attendance

    put transfer_admin_semester_klass_course_attendance_path(
      attendance.course.semester_klass, attendance.course, attendance
    )

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_equal "normal", attendance.reload.status
    assert_equal "in", klass_students(:ks_1).reload.status
  end

  test "transfer rejects a class that already contains the student" do
    attendance = prepared_attendance
    target = SemesterKlass.create!(
      semester: semesters(:semester_previous), campuse: campuses(:campuse_1),
      grade: grades(:grade_7), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      genre: "JY", seq: 88, times: 1
    )
    KlassStudent.create!(semester_klass: target, student: students(:student_7_1), status: "in")

    put transfer_admin_semester_klass_course_attendance_path(
      attendance.course.semester_klass, attendance.course, attendance,
      target_semester_klass_id: target.id
    )

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_equal "normal", attendance.reload.status
    assert_equal "in", klass_students(:ks_1).reload.status
  end

  private
    def prepared_attendance
      course = semester_klasses(:sk_math_1).courses.find_by!(seq: 1)
      course.start!
      course.attendances.find_by!(klass_student_id: klass_students(:ks_1).id)
    end

    def mark(attendance, status)
      put mark_admin_semester_klass_course_attendance_path(
        attendance.course.semester_klass, attendance.course, attendance, status: status
      )
    end
end
