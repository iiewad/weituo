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
end
