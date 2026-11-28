require "application_system_test_case"

class ReservationBatchTest < ApplicationSystemTestCase
  test "预留表勾选学员后按分组批量进班" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    # 学员年级与班级年级一致才可进班：先升级到目标年级
    students(:student_7_1).update!(grade: grades(:grade_8))
    students(:student_7_2).update!(grade: grades(:grade_8))
    attrs = {
      semester: semesters(:semester_next), subject: subjects(:math), grade: grades(:grade_8),
      teacher: teachers(:math_teacher_1), genre: "JY",
      source_semester: sk.semester, source_semester_klass: sk
    }
    first = Reservation.create!(student: students(:student_7_1), **attrs)
    second = Reservation.create!(student: students(:student_7_2), **attrs)

    visit switch_thread_semester_admin_semester_path(semesters(:semester_next))
    visit admin_reservations_path

    find("input[data-reservation-select-target='rowCheckbox'][value='#{first.id}']").check
    find("input[data-reservation-select-target='rowCheckbox'][value='#{second.id}']").check
    click_button "批量进班"

    within("#batch-enroll-drawer") do
      key = first.group_key_string
      assert_selector "[data-batch-group='#{key}']", text: "选中 2 人"
      assert_selector "[data-batch-group='#{key}']", text: students(:student_7_1).name
      assert_selector "[data-batch-group='#{key}']", text: students(:student_7_2).name
      assert_selector "[data-batch-group='#{key}'] select[name='groups[#{key}][grade_id]']"
      assert_selector "[data-batch-group='#{key}'] select[name='groups[#{key}][genre]']"
      assert_selector "[data-batch-group='#{key}'] select[name='groups[#{key}][phase]']"
      assert_selector "[data-batch-group='#{key}'] select[name='groups[#{key}][teacher_id]']"
      find("[data-batch-group='#{key}'] input[name='groups[#{key}][times]']").set(6)

      choose "加入已有班级"
      assert_selector "[data-reservation-select-target='joinPane']", text: "暂无可加入的下学期班级"

      choose "按分组生成新班级"
      click_button "确认进班"
    end

    assert_text "已生成 1 个班级"
    klass = SemesterKlass.where(semester: semesters(:semester_next)).order(:id).last
    assert_equal 6, klass.times
    assert_equal [ students(:student_7_1).id, students(:student_7_2).id ].sort,
                 klass.klass_students.pluck(:student_id).sort
  end
end
