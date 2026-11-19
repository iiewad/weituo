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
    find("[data-floating-card-target='trigger']").hover
    find("button[data-action='transfer-drawer#open']", text: "转出").click

    assert find("#drawer-transfer", visible: :all).checked?, "转出抽屉应被打开"

    choose "target_semester_klass_id_#{target.id}"
    click_button "确认转出"

    assert_text "已将"
    assert_equal "transfer", attendance.reload.status
    assert_equal "transfer", klass_students(:ks_2).reload.status
    assert target.klass_students.exists?(student_id: students(:student_7_1).id)
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
    find("[data-floating-card-target='trigger']").hover
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
