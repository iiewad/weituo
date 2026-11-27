require "application_system_test_case"

class AttendanceSearchTest < ApplicationSystemTestCase
  test "考勤表可以按姓名搜索学员" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    KlassStudent.create!(semester_klass: sk, student: students(:student_7_2), status: "in")

    visit admin_semester_klass_path(sk)

    assert_selector "tr[data-attendance-search-target='row']", count: 2

    fill_in "搜索学员姓名", with: "7_学生2"
    assert_selector "tr[data-attendance-search-target='row']", count: 1
    assert_text "匹配 1 人"

    fill_in "搜索学员姓名", with: "不存在"
    assert_no_selector "tr[data-attendance-search-target='row']"
    assert_text "没有匹配的学员"

    fill_in "搜索学员姓名", with: ""
    assert_selector "tr[data-attendance-search-target='row']", count: 2
  end

  test "考勤行流式更新后搜索过滤与勾选计数仍生效" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    KlassStudent.create!(semester_klass: sk, student: students(:student_7_2), status: "in")
    course = sk.courses.find_by!(seq: 1)
    course.update!(start_date: Date.current)
    course.attendances.create!(klass_student: klass_students(:ks_2), status: "normal")

    visit admin_semester_klass_path(sk)

    fill_in "搜索学员姓名", with: "7_学生1"
    row = find("tr#klass_student_#{klass_students(:ks_2).id}")
    within(row) { find("input[data-attendance-select-target='rowCheckbox']").check }
    assert_text "已选 1 人"

    within(row) { find("[data-floating-card-target='trigger']").click }
    within(row) { click_button "缺课" }

    # 只替换该行；替换后的行重新应用搜索过滤，勾选计数按新行重算
    assert_selector "tr#klass_student_#{klass_students(:ks_2).id} [data-floating-card-target='trigger']", text: "缺"
    assert_selector "tr[data-attendance-search-target='row']", count: 1
    assert_text "匹配 1 人"
    assert_no_text "已选 1 人"
    assert_equal "absent", course.attendances.find_by!(klass_student_id: klass_students(:ks_2).id).reload.status
  end
end
