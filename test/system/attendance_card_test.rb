require "application_system_test_case"

class AttendanceCardTest < ApplicationSystemTestCase
  test "考勤操作卡不被表格裁切并可切换状态" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    course = sk.courses.create!(seq: 1, start_date: Date.current)
    attendance = course.attendances.create!(klass_student: klass_students(:ks_2), status: "normal")

    visit admin_semester_klass_path(sk)
    find("[data-floating-card-target='trigger']").hover

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
end
