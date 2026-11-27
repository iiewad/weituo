require "application_system_test_case"

class AttendanceTransferTest < ApplicationSystemTestCase
  test "点击转出后在抽屉中选择目标班级完成转班" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.find_by!(seq: 1)
    course.update!(start_date: Date.current)
    attendance = course.attendances.create!(klass_student: klass_students(:ks_2), status: "normal")
    target = semester_klasses(:sk_math_3)

    visit admin_semester_klass_path(sk)
    find("[data-floating-card-target='trigger']").click
    find("button[data-action='transfer-drawer#open']", text: "转出").click

    assert find("#drawer-transfer", visible: :all).checked?, "转出抽屉应被打开"

    choose "target_semester_klass_id_#{target.id}"
    click_button "确认转出"

    assert_text "已将"
    assert_equal "transfer", attendance.reload.status
    assert_equal "transfer", klass_students(:ks_2).reload.status
    assert target.klass_students.exists?(student_id: students(:student_7_1).id)
  end

  test "转出后可在转入班反向转出回原班" do
    sign_in
    class_a = semester_klasses(:sk_math_2)
    class_b = semester_klasses(:sk_math_3)
    student = students(:student_7_1)

    a_first = class_a.courses.find_by!(seq: 1)
    a_first.update!(start_date: Date.current)
    a_first.attendances.create!(klass_student: klass_students(:ks_2), status: "normal")

    visit admin_semester_klass_path(class_a)
    find("[data-floating-card-target='trigger']").click
    find("button[data-action='transfer-drawer#open']", text: "转出").click
    choose "target_semester_klass_id_#{class_b.id}"
    click_button "确认转出"
    assert_equal "transfer", klass_students(:ks_2).reload.status

    b_first = class_b.courses.find_by!(seq: 1)
    b_first.update!(start_date: Date.current)
    b_ks = class_b.klass_students.find_by!(student_id: student.id)
    b_first.attendances.find_or_create_by!(klass_student: b_ks)

    visit admin_semester_klass_path(class_b)
    find("[data-floating-card-target='trigger']").click
    find("button[data-action='transfer-drawer#open']", text: "转出").click

    # 原班处于「转出」状态，重新显示在可选列表中
    assert_selector "label[data-class-id='#{class_a.id}']", visible: true
    choose "target_semester_klass_id_#{class_a.id}"
    click_button "确认转出"

    assert_text "已将"
    assert_equal "in", klass_students(:ks_2).reload.status
    assert_equal "transfer", b_ks.reload.status
    assert_no_selector "form[action='#{reinstate_admin_semester_klass_klass_student_path(class_b, b_ks)}']"
  end

  test "页面底部可撤销退课并恢复在班" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    ks = klass_students(:ks_2)
    course = sk.courses.find_by!(seq: 1)
    course.update!(start_date: Date.current)
    attendance = course.attendances.create!(klass_student: ks, status: "normal")
    attendance.mark_quit!

    visit admin_semester_klass_path(sk)
    find("summary", text: /转出 \/ 退课学员/).click
    within(find("li", text: ks.student.identity_label)) do
      accept_confirm(/撤销/) { click_button "撤销" }
    end

    assert_text "已撤销"
    assert_equal "in", ks.reload.status
    assert_equal "normal", attendance.reload.status
  end

  test "转出抽屉隐藏学员已在的班级并支持筛选" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.find_by!(seq: 1)
    course.update!(start_date: Date.current)
    course.attendances.create!(klass_student: klass_students(:ks_2), status: "normal")

    enrolled_target = semester_klasses(:sk_math_3)
    KlassStudent.create!(semester_klass: enrolled_target, student: students(:student_7_1), status: "in")
    eng_target = SemesterKlass.create!(
      semester: semesters(:semester_current), campuse: campuses(:campuse_1),
      grade: grades(:grade_7), subject: subjects(:eng), teacher: teachers(:eng_teacher_1),
      genre: "JY", seq: 99, times: 1
    )

    visit admin_semester_klass_path(sk)
    find("[data-floating-card-target='trigger']").click
    find("button[data-action='transfer-drawer#open']", text: "转出").click

    # 默认按当前班级科目（数学）筛选；学员已在的数学班不展示
    assert_equal sk.subject_id.to_s, find("#transfer_subject_filter").value
    assert_no_selector "label[data-class-id='#{enrolled_target.id}']", visible: true
    assert_no_selector "label[data-class-id='#{eng_target.id}']", visible: true
    assert_selector "[data-transfer-drawer-target='empty']", visible: true

    form = find("[data-transfer-drawer-target='form']")
    within(form) do
      select "英语", from: "科目"
      assert_selector "label[data-class-id='#{eng_target.id}']", visible: true
      assert_no_selector "label[data-class-id='#{enrolled_target.id}']", visible: true
      assert_not find("[data-transfer-drawer-target='submit']").disabled?

      select "数学", from: "科目"
      assert_no_selector "label[data-class-id='#{eng_target.id}']", visible: true
      assert_selector "[data-transfer-drawer-target='empty']", visible: true
      assert find("[data-transfer-drawer-target='submit']").disabled?, "没有可转班级时应禁用提交"
    end
  end
end
