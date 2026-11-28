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

  test "mark normal restores a mistaken absence" do
    attendance = prepared_attendance
    attendance.mark_absent!

    mark(attendance, "normal")

    assert_equal "normal", attendance.reload.status
  end

  test "mark quit survives an archived enrollment" do
    attendance = prepared_attendance
    klass_students(:ks_2).archive!

    mark(attendance, "quit")

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_equal "quit", attendance.reload.status
    assert klass_students(:ks_2).reload.archived_at.present?
  end

  test "mark rejects an unstarted course" do
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.find_by!(seq: 2)
    attendance = course.attendances.create!(klass_student: klass_students(:ks_2))

    mark(attendance, "absent")

    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "尚未开课", flash[:alert]
    assert_equal "normal", attendance.reload.status
    assert_nil attendance.reload.marked_by
  end

  test "transfer rejects an unstarted source course" do
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.find_by!(seq: 2)
    attendance = course.attendances.create!(klass_student: klass_students(:ks_2))
    target = semester_klasses(:sk_math_3)

    put transfer_admin_semester_klass_course_attendance_path(
      sk, course, attendance, target_semester_klass_id: target.id
    )

    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "尚未开课", flash[:alert]
    assert_equal "normal", attendance.reload.status
    assert_equal "in", klass_students(:ks_2).reload.status
  end

  test "mark filled after an absence" do
    attendance = prepared_attendance
    attendance.mark_absent!

    mark(attendance, "filled")

    assert_equal "filled", attendance.reload.status
  end

  test "mark streams a row replacement for a plain status" do
    attendance = prepared_attendance
    ks = klass_students(:ks_2)

    put mark_admin_semester_klass_course_attendance_path(
      attendance.course.semester_klass, attendance.course, attendance
    ), params: { status: "absent" }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action='replace'][target='klass_student_#{ks.id}']"
    assert_select "turbo-stream[action='update'][target='flash']"
    assert_includes response.body, "tr id=\"klass_student_#{ks.id}\""
    assert_equal "absent", attendance.reload.status
    assert_equal users(:one), attendance.marked_by
  end

  test "mark streams a second status change on the same row" do
    attendance = prepared_attendance
    attendance.mark_absent!
    ks = klass_students(:ks_2)

    put mark_admin_semester_klass_course_attendance_path(
      attendance.course.semester_klass, attendance.course, attendance
    ), params: { status: "filled" }, as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action='replace'][target='klass_student_#{ks.id}']"
    assert_equal "filled", attendance.reload.status
  end

  test "mark transfer_in streams a row replacement and leaves the enrollment untouched" do
    attendance = prepared_attendance
    ks = klass_students(:ks_2)

    put mark_admin_semester_klass_course_attendance_path(
      attendance.course.semester_klass, attendance.course, attendance
    ), params: { status: "transfer_in" }, as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action='replace'][target='klass_student_#{ks.id}']"
    assert_equal "transfer_in", attendance.reload.status
    assert_equal users(:one), attendance.marked_by
    assert_equal "in", ks.reload.status
    assert_nil ks.reload.transfer_in_seq
    # 手动标记的转入行提供「恢复正常」，流式响应里没有其它操作按钮
    assert_select "form button", text: "恢复正常"
    assert_select "form button", text: "标记为转入", count: 0
  end

test "mark transfer_out streams a row replacement and leaves the enrollment untouched" do
    attendance = prepared_attendance
    ks = klass_students(:ks_2)

    put mark_admin_semester_klass_course_attendance_path(
      attendance.course.semester_klass, attendance.course, attendance
    ), params: { status: "transfer_out" }, as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action='replace'][target='klass_student_#{ks.id}']"
    assert_equal "transfer", attendance.reload.status
    assert attendance.manual_transfer_out?
    assert_equal users(:one), attendance.marked_by
    assert_equal "in", ks.reload.status
    # 手动标记的转出行提供「恢复正常」，不再提供其它操作
    assert_select "form button", text: "恢复正常"
    assert_select "form button", text: "标记为转出", count: 0
  end

  test "mark normal restores a manually marked transfer_out" do
    attendance = prepared_attendance
    attendance.mark_transfer_out!

    mark(attendance, "normal")

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_equal "normal", attendance.reload.status
    assert_not attendance.reload.manual_transfer_out?
  end

  test "mark refuses to restore a real transfer" do
    attendance = prepared_attendance
    attendance.mark_transfer!

    mark(attendance, "normal")

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_match "无法改为「正常」", flash[:alert]
    assert_equal "transfer", attendance.reload.status
  end


  test "mark normal restores a manually marked transfer_in" do
    attendance = prepared_attendance
    attendance.update!(status: "transfer_in")

    mark(attendance, "normal")

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_equal "normal", attendance.reload.status
  end

  test "mark refuses to change an auto-generated transfer_in" do
    attendance = prepared_attendance
    klass_students(:ks_2).update!(transfer_source_klass: semester_klasses(:sk_math_3), transfer_in_seq: 2)
    attendance.update!(status: "transfer_in")

    mark(attendance, "normal")

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_match "无法改为「正常」", flash[:alert]
    assert_equal "transfer_in", attendance.reload.status
  end

  test "attendance card offers 标记为转入 / 标记为转出 for in-class rows only" do
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.find_by!(seq: 1)
    course.start!
    # 全部课次结课后才展示标记转入 / 转出的入口
    sk.courses.where(start_date: nil).update_all(start_date: Date.current)
    in_class = course.attendances.find_by!(klass_student: klass_students(:ks_2))
    quit_ks = KlassStudent.create!(semester_klass: sk, student: students(:student_7_2), status: "out")
    manual_ks = KlassStudent.create!(semester_klass: sk, student: students(:student_7_3), status: "in")
    quit = course.attendances.create!(klass_student: quit_ks, status: "quit")
    manual = course.attendances.create!(klass_student: manual_ks, status: "transfer_in")

    get admin_semester_klass_path(sk)

    assert_response :success
    in_class_card = "form[action='#{mark_admin_semester_klass_course_attendance_path(sk, course, in_class, status: "transfer_in")}']"
    assert_select in_class_card, text: "标记为转入"
    assert_select "form[action='#{mark_admin_semester_klass_course_attendance_path(sk, course, quit, status: "transfer_in")}']", count: 0
    assert_select "form[action='#{mark_admin_semester_klass_course_attendance_path(sk, course, manual, status: "normal")}']", text: "恢复正常"

    transfer_out_card = "form[action='#{mark_admin_semester_klass_course_attendance_path(sk, course, in_class, status: "transfer_out")}']"
    assert_select transfer_out_card, text: "标记为转出"
    assert_select "form[action='#{mark_admin_semester_klass_course_attendance_path(sk, course, quit, status: "transfer_out")}']", count: 0
  end

  test "attendance card offers 恢复正常 for a manually marked transfer_out only" do
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.find_by!(seq: 1)
    course.start!
    manual_ks = KlassStudent.create!(semester_klass: sk, student: students(:student_7_3), status: "in")
    manual = course.attendances.create!(klass_student: manual_ks, status: "transfer", manual_transfer_out: true)
    real_ks = KlassStudent.create!(semester_klass: sk, student: students(:student_7_2), status: "transfer")
    real = course.attendances.create!(klass_student: real_ks, status: "transfer")

    get admin_semester_klass_path(sk)

    assert_response :success
    assert_select "form[action='#{mark_admin_semester_klass_course_attendance_path(sk, course, manual, status: "normal")}']", text: "恢复正常"
    assert_select "form[action='#{mark_admin_semester_klass_course_attendance_path(sk, course, real, status: "normal")}']", count: 0
    assert_select "form[action='#{mark_admin_semester_klass_course_attendance_path(sk, course, manual, status: "transfer_out")}']", count: 0
  end

  test "attendance card hides the manual transfer entries until every course has started" do
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.find_by!(seq: 1)
    course.start!
    attendance = course.attendances.find_by!(klass_student: klass_students(:ks_2))

    get admin_semester_klass_path(sk)

    assert_response :success
    assert_select "form[action='#{mark_admin_semester_klass_course_attendance_path(sk, course, attendance, status: "transfer_in")}']", count: 0
    assert_select "form[action='#{mark_admin_semester_klass_course_attendance_path(sk, course, attendance, status: "transfer_out")}']", count: 0
    # 常规状态操作不受影响
    assert_select "form[action='#{mark_admin_semester_klass_course_attendance_path(sk, course, attendance, status: "absent")}']", text: "缺课"

    sk.courses.where(start_date: nil).update_all(start_date: Date.current)
    get admin_semester_klass_path(sk)

    assert_response :success
    assert_select "form[action='#{mark_admin_semester_klass_course_attendance_path(sk, course, attendance, status: "transfer_in")}']", text: "标记为转入"
    assert_select "form[action='#{mark_admin_semester_klass_course_attendance_path(sk, course, attendance, status: "transfer_out")}']", text: "标记为转出"
  end

  test "mark streams quit as a redirect so rosters and badges refresh" do
    attendance = prepared_attendance
    sk = attendance.course.semester_klass

    put mark_admin_semester_klass_course_attendance_path(sk, attendance.course, attendance),
      params: { status: "quit" }, as: :turbo_stream

    assert_response :redirect
    assert_redirected_to admin_semester_klass_path(sk)
    assert_equal "quit", attendance.reload.status
  end

  test "mark rejects an unstarted course for stream requests" do
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.find_by!(seq: 2)
    attendance = course.attendances.create!(klass_student: klass_students(:ks_2))

    put mark_admin_semester_klass_course_attendance_path(sk, course, attendance),
      params: { status: "absent" }, as: :turbo_stream

    assert_response :redirect
    assert_redirected_to admin_semester_klass_path(sk)
    assert_match "尚未开课", flash[:alert]
    assert_equal "normal", attendance.reload.status
  end

  test "mark rejoin after quitting" do
    attendance = prepared_attendance
    attendance.mark_quit!

    mark(attendance, "rejoin")

    assert_equal "normal", attendance.reload.status
  end

  test "mark quit cascades to later started courses and the enrollment" do
    attendance = prepared_attendance
    later = semester_klasses(:sk_math_2).courses.find_by!(seq: 2)
    later.start!

    mark(attendance, "quit")

    assert_equal "out", klass_students(:ks_2).reload.status
    assert_equal "quit", later.attendances.find_by!(klass_student_id: klass_students(:ks_2).id).status
    assert_nil semester_klasses(:sk_math_2).courses.find_by!(seq: 3)
      .attendances.find_by(klass_student_id: klass_students(:ks_2).id)
  end

  test "cannot mark attendance from a semester that is not current" do
    sk = semester_klasses(:sk_math_1)
    course = sk.courses.find_by!(seq: 1)
    course.start!
    attendance = course.attendances.find_by!(klass_student_id: klass_students(:ks_1).id)

    put mark_admin_semester_klass_course_attendance_path(sk, course, attendance, status: "absent")

    assert_response :not_found
    assert_equal "normal", attendance.reload.status
  end

  test "switching semester allows backfilling attendance for that semester" do
    sk = semester_klasses(:sk_math_1)
    course = sk.courses.find_by!(seq: 1)
    course.start!
    attendance = course.attendances.find_by!(klass_student_id: klass_students(:ks_1).id)

    get switch_thread_semester_admin_semester_path(semesters(:semester_previous))
    put mark_admin_semester_klass_course_attendance_path(sk, course, attendance, status: "absent")

    assert_redirected_to admin_semester_klass_path(sk)
    assert_equal "absent", attendance.reload.status
  end

  test "cannot mark attendance from another campus" do
    other_campuse = Campuse.create!(name: "其他校区", school: schools(:school_1))
    other_semester = other_campuse.semesters.create!(name: "其他学期", seq: 1)
    sk = SemesterKlass.create!(
      campuse: other_campuse, semester: other_semester,
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
    assert_equal "in", klass_students(:ks_2).reload.status
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
    target = semester_klasses(:sk_math_3)

    put transfer_admin_semester_klass_course_attendance_path(
      attendance.course.semester_klass, attendance.course, attendance,
      target_semester_klass_id: target.id
    )

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_equal "transfer", attendance.reload.status
    assert_equal target.id, attendance.transfer_target_klass_id
    assert_equal "transfer", klass_students(:ks_2).reload.status
    assert target.klass_students.exists?(student_id: students(:student_7_1).id)
  end

  test "transfer marks earlier started target courses as transfer_in and keeps source attendance in the source" do
    source = semester_klasses(:sk_math_2)
    source.courses.order(:seq).limit(3).each(&:start!)
    ks = klass_students(:ks_2)
    source.courses.find_by!(seq: 1).attendances.find_by!(klass_student_id: ks.id).mark_personal_leave!
    source.courses.find_by!(seq: 2).attendances.find_by!(klass_student_id: ks.id).mark_absent!
    transfer_attendance = source.courses.find_by!(seq: 3).attendances.find_by!(klass_student_id: ks.id)

    target = semester_klasses(:sk_math_3)
    target.courses.order(:seq).limit(2).each(&:start!)

    put transfer_admin_semester_klass_course_attendance_path(
      source, source.courses.find_by!(seq: 3), transfer_attendance,
      target_semester_klass_id: target.id
    )

    assert_redirected_to admin_semester_klass_path(source)
    target_ks = target.klass_students.find_by!(student_id: ks.student_id)
    # 目标班入班前已开课次统一标记「转入」，不再沿用源班考勤
    assert_equal "transfer_in", target.courses.find_by!(seq: 1).attendances.find_by!(klass_student_id: target_ks.id).status
    assert_equal "transfer_in", target.courses.find_by!(seq: 2).attendances.find_by!(klass_student_id: target_ks.id).status
    assert_nil target.courses.find_by!(seq: 3).attendances.find_by(klass_student_id: target_ks.id)
    # 源班真实考勤原样保留在源班
    assert_equal "personal_leave", source.courses.find_by!(seq: 1).attendances.find_by!(klass_student_id: ks.id).status
    assert_equal "absent", source.courses.find_by!(seq: 2).attendances.find_by!(klass_student_id: ks.id).status
    # 转入来源与入班课次记录在目标班报名上：入班课次按源班转出课次（第 3 课）对齐为第 4 课
    assert_equal source, target_ks.reload.transfer_source_klass
    assert_equal 4, target_ks.transfer_in_seq

    # 入班前的课次后补开课时标记「转入」，入班课次起正常出勤
    target.courses.find_by!(seq: 3).start!
    assert_equal "transfer_in", target.courses.find_by!(seq: 3).attendances.find_by!(klass_student_id: target_ks.id).status
    target.courses.find_by!(seq: 4).start!
    assert_equal "normal", target.courses.find_by!(seq: 4).attendances.find_by!(klass_student_id: target_ks.id).status
  end

  test "transfer into a fresh class marks later-started courses before the entry as transfer_in" do
    source = semester_klasses(:sk_math_2)
    source.courses.order(:seq).limit(3).each(&:start!)
    ks = klass_students(:ks_2)
    transfer_attendance = source.courses.find_by!(seq: 3).attendances.find_by!(klass_student_id: ks.id)
    target = semester_klasses(:sk_math_3)

    # 先转入全新目标班（入班课次按源班转出课次对齐为第 4 课），再批量补开第 1-5 课
    transfer_to(transfer_attendance, target)
    target_ks = target.klass_students.find_by!(student_id: ks.student_id)
    assert_equal 4, target_ks.transfer_in_seq

    target.courses.order(:seq).limit(5).each(&:start!)
    (1..3).each do |seq|
      row = target.courses.find_by!(seq: seq).attendances.find_by!(klass_student_id: target_ks.id)
      assert_equal "transfer_in", row.status, "第 #{seq} 课应为转入"
    end
    (4..5).each do |seq|
      row = target.courses.find_by!(seq: seq).attendances.find_by!(klass_student_id: target_ks.id)
      assert_equal "normal", row.status, "第 #{seq} 课应正常出勤"
    end
  end

  test "transfer rejects a target class that has already finished" do
    attendance = prepared_attendance
    target = semester_klasses(:sk_math_3)
    target.courses.update_all(start_date: Date.current)

    put transfer_admin_semester_klass_course_attendance_path(
      attendance.course.semester_klass, attendance.course, attendance,
      target_semester_klass_id: target.id
    )

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_match "课程已全部开始", flash[:alert]
    assert_equal "normal", attendance.reload.status
    assert_equal "in", klass_students(:ks_2).reload.status
    assert_not target.klass_students.exists?(student_id: students(:student_7_1).id)
  end

  test "transfer requires an available target class" do
    attendance = prepared_attendance

    put transfer_admin_semester_klass_course_attendance_path(
      attendance.course.semester_klass, attendance.course, attendance
    )

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_equal "normal", attendance.reload.status
    assert_equal "in", klass_students(:ks_2).reload.status
  end

  test "transfer rejects a class that already contains the student" do
    attendance = prepared_attendance
    target = SemesterKlass.create!(
      semester: semesters(:semester_current), campuse: campuses(:campuse_1),
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
    assert_equal "in", klass_students(:ks_2).reload.status
  end

  test "transfer can move a student back to the class they left" do
    class_a = semester_klasses(:sk_math_2)
    class_b = semester_klasses(:sk_math_3)
    ks = klass_students(:ks_2)

    a_first = class_a.courses.find_by!(seq: 1)
    a_first.start!
    a_transfer_row = a_first.attendances.find_by!(klass_student_id: ks.id)
    transfer_to(a_transfer_row, class_b)
    assert_equal "transfer", ks.reload.status

    b_first = class_b.courses.find_by!(seq: 1)
    b_second = class_b.courses.find_by!(seq: 2)
    [ b_first, b_second ].each(&:start!)
    b_ks = class_b.klass_students.find_by!(student_id: ks.student_id)
    b_transfer_row = b_second.attendances.find_by!(klass_student_id: b_ks.id)

    transfer_to(b_transfer_row, class_a)

    assert_redirected_to admin_semester_klass_path(class_b)
    assert_equal "in", ks.reload.status
    # 原班的转出行改为「转入（来自 B）」，不再沿用来源班同课次状态
    assert_equal "transfer_in", a_transfer_row.reload.status
    assert_equal "transfer", b_ks.reload.status
    assert_equal "transfer", b_transfer_row.reload.status
    assert_equal class_a.id, b_transfer_row.transfer_target_klass_id
  end

  test "a student can be transferred back and forth repeatedly" do
    class_a = semester_klasses(:sk_math_2)
    class_b = semester_klasses(:sk_math_3)
    ks = klass_students(:ks_2)

    a_first = class_a.courses.find_by!(seq: 1)
    a_first.start!
    transfer_to(a_first.attendances.find_by!(klass_student_id: ks.id), class_b)

    # B 班入班课次对齐为第 2 课：第 1 课后补开课标记「转入」，第 2 课起正常出勤
    b_first = class_b.courses.find_by!(seq: 1)
    b_second = class_b.courses.find_by!(seq: 2)
    [ b_first, b_second ].each(&:start!)
    b_ks = class_b.klass_students.find_by!(student_id: ks.student_id)
    assert_equal "transfer_in", b_first.attendances.find_by!(klass_student_id: b_ks.id).status
    transfer_to(b_second.attendances.find_by!(klass_student_id: b_ks.id), class_a)
    assert_equal "in", ks.reload.status

    # 回到 A 班入班课次对齐为第 3 课：第 2 课后补开课标记「转入」，第 3 课起正常出勤
    a_second = class_a.courses.find_by!(seq: 2)
    a_third = class_a.courses.find_by!(seq: 3)
    [ a_second, a_third ].each(&:start!)
    assert_equal "transfer_in", a_second.attendances.find_by!(klass_student_id: ks.id).status
    transfer_to(a_third.attendances.find_by!(klass_student_id: ks.id), class_b)

    assert_equal "transfer", ks.reload.status
    assert_equal "in", b_ks.reload.status
  end

  test "transferring back keeps the original class's real attendance statuses" do
    class_a = semester_klasses(:sk_math_2)
    class_b = semester_klasses(:sk_math_3)
    ks = klass_students(:ks_2)

    a_first = class_a.courses.find_by!(seq: 1)
    a_second = class_a.courses.find_by!(seq: 2)
    [ a_first, a_second ].each(&:start!)
    a_first_row = a_first.attendances.find_by!(klass_student_id: ks.id)
    a_first_row.mark_sick_leave!
    a_second_row = a_second.attendances.find_by!(klass_student_id: ks.id)

    transfer_to(a_second_row, class_b)
    assert_equal "transfer", a_second_row.reload.status
    assert_equal "sick_leave", a_first_row.reload.status

    b_first = class_b.courses.find_by!(seq: 1)
    b_second = class_b.courses.find_by!(seq: 2)
    b_third = class_b.courses.find_by!(seq: 3)
    [ b_first, b_second, b_third ].each(&:start!)
    b_ks = class_b.klass_students.find_by!(student_id: ks.student_id)
    # B 班入班课次对齐为第 3 课：第 1、2 课后补开课标记「转入」，第 3 课起正常出勤
    assert_equal "transfer_in", b_first.attendances.find_by!(klass_student_id: b_ks.id).status
    b_third.attendances.find_by!(klass_student_id: b_ks.id).mark_absent!

    # 从 B 第 3 课转回 A：入班课次对齐为第 4 课，A 第 1、2 课是入班前已开课次，标记「转入（来自 B）」
    transfer_to(b_third.attendances.find_by!(klass_student_id: b_ks.id), class_a)

    # A 第 1 课的真实考勤（病假）原样保留，A 第 2 课原「转出」行改为「转入」
    assert_equal "sick_leave", a_first_row.reload.status
    assert_equal "transfer_in", a_second_row.reload.status
    assert_equal "in", ks.reload.status
    assert_equal class_b, ks.reload.transfer_source_klass
    assert_equal 4, ks.transfer_in_seq
  end

  test "mark refuses rejoin for a transferred attendance" do
    attendance = prepared_attendance
    transfer_to(attendance, semester_klasses(:sk_math_3))
    assert_equal "transfer", attendance.reload.status

    mark(attendance, "rejoin")

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_match "无法改为「重新加入」", flash[:alert]
    assert_equal "transfer", attendance.reload.status
    assert_equal "transfer", klass_students(:ks_2).reload.status
  end

  test "transfer rejects a class where the student already quit" do
    attendance = prepared_attendance
    target = SemesterKlass.create!(
      semester: semesters(:semester_current), campuse: campuses(:campuse_1),
      grade: grades(:grade_7), subject: subjects(:math), teacher: teachers(:math_teacher_1),
      genre: "JY", seq: 89, times: 1
    )
    KlassStudent.create!(semester_klass: target, student: students(:student_7_1), status: "out")

    transfer_to(attendance, target)

    assert_redirected_to admin_semester_klass_path(attendance.course.semester_klass)
    assert_match "曾在", flash[:alert]
    assert_equal "normal", attendance.reload.status
    assert_equal "in", klass_students(:ks_2).reload.status
    assert_equal "out", target.klass_students.find_by!(student_id: students(:student_7_1).id).status
  end

  private
    def transfer_to(attendance, target)
      put transfer_admin_semester_klass_course_attendance_path(
        attendance.course.semester_klass, attendance.course, attendance,
        target_semester_klass_id: target.id
      )
    end

    def prepared_attendance
      course = semester_klasses(:sk_math_2).courses.find_by!(seq: 1)
      course.start!
      course.attendances.find_by!(klass_student_id: klass_students(:ks_2).id)
    end

    def mark(attendance, status)
      put mark_admin_semester_klass_course_attendance_path(
        attendance.course.semester_klass, attendance.course, attendance, status: status
      )
    end
end
