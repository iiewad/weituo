require "application_system_test_case"

class CourseDateTest < ApplicationSystemTestCase
  test "表头日期可修改开课日期并顺延后续已开课课次" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    first, second, third = [ 1, 2, 3 ].map { |seq| sk.courses.find_by!(seq: seq) }
    first.start!(Date.new(2026, 3, 1))
    second.start!(Date.new(2026, 3, 8))
    third.start!(Date.new(2026, 3, 15))

    visit admin_semester_klass_path(sk)

    find("[data-course-date-target='trigger'][data-course-date-seq='1']").click
    assert_selector "h2", text: "修改开课日期 · 第 1 课"
    assert_text "原开课日期 2026-03-01"

    set_course_date("2026-03-02")
    check "course_date_cascade"
    fill_in "course_date_interval", with: 7
    assert_text "第 2–3 课（共 2 次）从 03-09 起按 7 天顺延，至 03-16。"
    click_button "保存"

    assert_text "第 1 课开课日期已改为 03-02，第 2–3 课已按 7 天顺延（至 03-16）"
    assert_selector "[data-course-date-target='trigger'][data-course-date-seq='1']", text: "03-02"
    assert_selector "[data-course-date-target='trigger'][data-course-date-seq='2']", text: "03-09"
    assert_selector "[data-course-date-target='trigger'][data-course-date-seq='3']", text: "03-16"
    assert_equal [ Date.new(2026, 3, 2), Date.new(2026, 3, 9), Date.new(2026, 3, 16) ],
      [ first, second, third ].map { |course| course.reload.start_date }
  end

  test "不勾选顺延时只改当前课次" do
    sign_in
    sk = semester_klasses(:sk_math_2)
    first, second = [ 1, 2 ].map { |seq| sk.courses.find_by!(seq: seq) }
    first.start!(Date.new(2026, 3, 1))
    second.start!(Date.new(2026, 3, 8))

    visit admin_semester_klass_path(sk)

    find("[data-course-date-target='trigger'][data-course-date-seq='2']").click
    set_course_date("2026-03-10")
    assert_no_checked_field "course_date_cascade"
    click_button "保存"

    assert_text "第 2 课开课日期已改为 03-10"
    assert_equal Date.new(2026, 3, 1), first.reload.start_date
    assert_equal Date.new(2026, 3, 10), second.reload.start_date
  end

  private
    # Selenium 往 date 输入框逐段输入会得到奇怪的值，直接写 value 再触发 input 更贴近原生日期选择器
    def set_course_date(value)
      execute_script(<<~JS)
        const input = document.querySelector("#course_date")
        input.value = "#{value}"
        input.dispatchEvent(new Event("input", { bubbles: true }))
      JS
    end
end
