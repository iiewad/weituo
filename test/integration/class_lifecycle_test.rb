require "test_helper"

class ClassLifecycleTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "从开班到结课的完整链路" do
    # 1. 开班：自动排 3 次课并导入学员
    assert_difference -> { SemesterKlass.count }, 1 do
      post admin_semester_klasses_path, params: { semester_klass: {
        semester_id: semesters(:semester_current).id,
        grade_id: grades(:grade_7).id,
        teacher_id: teachers(:math_teacher_1).id,
        campuse_id: campuses(:campuse_1).id,
        genre: "JY", seq: 77, times: 3, students_text: "7_学生2"
      } }
    end

    sk = SemesterKlass.order(:id).last
    assert_equal 3, sk.courses.count
    assert_equal [ 1, 2, 3 ], sk.courses.order(:seq).pluck(:seq)
    ks = sk.klass_students.find_by!(student_id: students(:student_7_2).id)
    assert_equal "in", ks.status

    # 2. 第 1 课开课，为在班学员生成正常考勤
    first = sk.courses.find_by!(seq: 1)
    put start_admin_semester_klass_course_path(sk, first)
    assert_response :redirect
    attendance = first.attendances.find_by!(klass_student_id: ks.id)
    assert_equal "normal", attendance.status

    # 3. 缺课后补课销假
    put mark_admin_semester_klass_course_attendance_path(sk, first, attendance, status: "absent")
    assert_equal "absent", attendance.reload.status
    put mark_admin_semester_klass_course_attendance_path(sk, first, attendance, status: "filled")
    assert_equal "filled", attendance.reload.status

    # 4. 退课：级联后续课次并转为退班
    put mark_admin_semester_klass_course_attendance_path(sk, first, attendance, status: "quit")
    assert_equal "quit", attendance.reload.status
    assert_equal "out", ks.reload.status
    later_courses = sk.courses.where("seq > 1").to_a
    later_courses.each do |course|
      assert_equal "quit", course.attendances.find_by!(klass_student_id: ks.id).status
    end

    # 5. 重新加入：后续课次恢复
    put mark_admin_semester_klass_course_attendance_path(sk, first, attendance, status: "rejoin")
    assert_equal "normal", attendance.reload.status
    later_courses.each do |course|
      assert_equal "normal", course.attendances.find_by!(klass_student_id: ks.id).status
    end

    # 6. 全部课次开课后结课
    assert_not sk.ended?
    later_courses.each do |course|
      put start_admin_semester_klass_course_path(sk, course)
    end
    assert sk.reload.ended?
  end

  test "复制历史班级到当前学期并重建课程与学员" do
    source = semester_klasses(:sk_math_1)

    assert_difference -> { SemesterKlass.count }, 1 do
      post copy_create_admin_semester_klasses_path, params: { semester_klass: {
        grade_id: source.grade_id,
        teacher_id: source.teacher_id,
        genre: source.genre,
        seq: 66, times: 4, students_text: "7_学生4"
      } }
    end

    copy = SemesterKlass.order(:id).last
    assert_response :redirect
    assert_equal semesters(:semester_current).id, copy.semester_id
    assert_equal campuses(:campuse_1).id, copy.campuse_id
    assert_equal 4, copy.courses.count
    assert_equal [ 1, 2, 3, 4 ], copy.courses.order(:seq).pluck(:seq)
    assert copy.klass_students.exists?(student_id: students(:student_7_4).id)
    assert_not copy.klass_students.exists?(student_id: students(:student_7_1).id)
  end
end
