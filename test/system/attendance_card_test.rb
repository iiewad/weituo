require "application_system_test_case"

class AttendanceCardTest < ApplicationSystemTestCase
  test "考勤卡点击打开，再次点击或点击外部关闭" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.find_by!(seq: 1)
    course.update!(start_date: Date.current)
    course.attendances.create!(klass_student: klass_students(:ks_2), status: "normal")

    visit admin_semester_klass_path(sk)
    trigger = find("[data-floating-card-target='trigger']")

    assert_no_selector "[data-floating-card-target='card']", visible: true
    trigger.click
    assert_selector "[data-floating-card-target='card']", visible: true
    trigger.click
    assert_no_selector "[data-floating-card-target='card']", visible: true

    trigger.click
    assert_selector "[data-floating-card-target='card']", visible: true
    find("h1").click
    assert_no_selector "[data-floating-card-target='card']", visible: true
  end

  test "考勤操作卡不被表格裁切并可切换状态" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.find_by!(seq: 1)
    course.update!(start_date: Date.current)
    attendance = course.attendances.create!(klass_student: klass_students(:ks_2), status: "normal")

    visit admin_semester_klass_path(sk)
    find("[data-floating-card-target='trigger']").click

    card = find("[data-floating-card-target='card']")
    assert card.visible?

    hit = page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector("[data-floating-card-target='card']");
        const rect = card.getBoundingClientRect();
        const element = document.elementFromPoint(rect.left + rect.width / 2, rect.bottom - 8);
        return element && element.closest("[data-floating-card-target='card']") ? "card" : (element ? element.className : "nil");
      })()
    JS
    assert_equal "card", hit, "卡片底部不应被表格容器裁切"

    within(card) { click_button "缺课" }

    assert_selector "[data-floating-card-target='trigger']", text: "缺"
    assert attendance.reload.absent?
  end

  test "考勤卡可把一格标记为转入并恢复正常" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    # 全部课次结课后才展示标记转入 / 转出的入口
    sk.courses.update_all(start_date: Date.current)
    course = sk.courses.find_by!(seq: 1)
    attendance = course.attendances.create!(klass_student: klass_students(:ks_2), status: "normal")

    visit admin_semester_klass_path(sk)
    open_first_course_card

    within("[data-floating-card-target='card']") { click_button "标记为转入" }

    assert_selector "[data-floating-card-target='trigger']", text: "入"
    assert attendance.reload.transfer_in?
    assert_equal "in", klass_students(:ks_2).reload.status

    open_first_course_card
    card = find("[data-floating-card-target='card']")
    assert_text "已标记为转入"
    within(card) { click_button "恢复正常" }

    assert_selector "[data-floating-card-target='trigger']", text: "√"
    assert attendance.reload.normal?
  end

  test "考勤卡可把一格标记为转出并恢复正常" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    # 全部课次结课后才展示标记转入 / 转出的入口
    sk.courses.update_all(start_date: Date.current)
    course = sk.courses.find_by!(seq: 1)
    attendance = course.attendances.create!(klass_student: klass_students(:ks_2), status: "normal")

    visit admin_semester_klass_path(sk)
    open_first_course_card

    within("[data-floating-card-target='card']") { click_button "标记为转出" }

    assert_selector "[data-floating-card-target='trigger']", text: "转"
    assert attendance.reload.transfer?
    assert attendance.manual_transfer_out?
    assert_equal "in", klass_students(:ks_2).reload.status

    open_first_course_card
    card = find("[data-floating-card-target='card']")
    assert_text "已标记为转出"
    within(card) { click_button "恢复正常" }

    assert_selector "[data-floating-card-target='trigger']", text: "√"
    assert attendance.reload.normal?
  end

  private
    # 全部课次结课后每格都有考勤入口，点开该行第 1 课的操作卡
    def open_first_course_card
      row = find("tr#klass_student_#{klass_students(:ks_2).id}")
      row.all("[data-floating-card-target='trigger']").first.click
    end
end
