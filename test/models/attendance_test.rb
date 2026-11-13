require "test_helper"

class AttendanceTest < ActiveSupport::TestCase
  # before_create :check_course_started
  test "create attendance" do
    course = semester_klasses(:sk_math_1).courses.first
    attendance = course.attendances.new(
      klass_student_id: klass_students(:ks_1).id
    )
    assert attendance.valid?
    assert attendance.status == "normal"
  end

  test "mark absent" do
    ks = klass_students(:ks_1)
    course = semester_klasses(:sk_math_1).courses.first
    course.start!
    attendance = course.attendances.find_by(klass_student_id: ks.id)
    attendance.mark_absent!
    assert_equal "absent", attendance.status
    assert attendance.mark_at["absent_at"].present?
    attendance.mark_filled!
    assert_equal "filled", attendance.status
    assert attendance.mark_at["filled_at"].present?
  end

  test "one attendance per klass student and course" do
    course = courses(:sk_1_course_1)
    ks = klass_students(:ks_1)
    course.attendances.create!(klass_student: ks)

    duplicate = course.attendances.new(klass_student: ks)
    assert_not duplicate.valid?
    assert duplicate.errors[:klass_student_id].any?
  end

  test "mark personal leave and sick leave after course started" do
    course = courses(:sk_1_course_1)
    course.start!
    attendance = attendance_for(course)

    attendance.mark_personal_leave!
    assert_equal "personal_leave", attendance.status
    assert attendance.mark_at["personal_leave_at"].present?

    attendance.mark_filled!
    attendance.mark_sick_leave!
    assert_equal "sick_leave", attendance.status
    assert attendance.mark_at["sick_leave_at"].present?
  end

  test "mark quit cascades to later courses and marks the enrollment out" do
    course = courses(:sk_1_course_1)
    course.start!
    attendance = attendance_for(course)

    attendance.mark_quit!

    assert_equal "quit", attendance.status
    assert_equal "out", klass_students(:ks_1).reload.status
    semester_klasses(:sk_math_1).courses.where("seq > ?", 1).each do |later|
      assert_equal "quit", attendance_for(later).status
    end
  end

  test "mark transfer cascades to later courses and marks the enrollment transfer" do
    course = courses(:sk_1_course_1)
    course.start!
    attendance = attendance_for(course)

    attendance.mark_transfer!

    assert_equal "transfer", attendance.status
    assert_equal "transfer", klass_students(:ks_1).reload.status
    semester_klasses(:sk_math_1).courses.where("seq > ?", 1).each do |later|
      assert_equal "transfer", attendance_for(later).status
    end
  end

  test "mark rejoin restores later course attendances" do
    course = courses(:sk_1_course_1)
    course.start!
    attendance = attendance_for(course)
    attendance.mark_quit!
    assert_equal "quit", attendance_for(semester_klasses(:sk_math_1).courses.find_by!(seq: 2)).status

    attendance.mark_rejoin!

    assert_equal "normal", attendance.status
    assert attendance.mark_at["rejoin_at"].present?
    semester_klasses(:sk_math_1).courses.where("seq > ?", 1).each do |later|
      assert_equal "normal", attendance_for(later).status
    end
  end

  test "status meta maps every status to a label, name and semantic color" do
    expected = {
      "normal" => [ "√", "正常", "success" ],
      "filled" => [ "补", "补课", "success" ],
      "absent" => [ "缺", "缺课", "error" ],
      "personal_leave" => [ "事", "事假", "warning" ],
      "sick_leave" => [ "病", "病假", "warning" ],
      "quit" => [ "退", "退课", "neutral" ],
      "transfer" => [ "转", "转出", "neutral" ]
    }

    expected.each do |status, (label, name, color)|
      attendance = Attendance.new(status: status)
      assert_equal label, attendance.status_label
      assert_equal name, attendance.status_name
      assert_equal color, attendance.badge_class
    end
  end

  test "status meta colors use only valid daisyUI v5 badge colors" do
    valid = %w[success error warning neutral ghost]
    Attendance::STATUS_META.each_value do |meta|
      assert_includes valid, meta[:color]
    end
  end

  test "unknown status falls back to safe display values" do
    attendance = Attendance.new
    attendance.status = nil
    assert_equal "—", attendance.status_label
    assert_equal "未录入", attendance.status_name
    assert_equal "ghost", attendance.badge_class
  end

  private
    def attendance_for(course)
      course.attendances.find_by!(klass_student_id: klass_students(:ks_1).id)
    end
end
