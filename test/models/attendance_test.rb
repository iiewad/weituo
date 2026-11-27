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
    course = semester_klasses(:sk_math_1).courses.find_by!(seq: 1)
    course.start!
    attendance = course.attendances.find_by(klass_student_id: ks.id)
    attendance.mark_absent!
    assert_equal "absent", attendance.status
    attendance.mark_filled!
    assert_equal "filled", attendance.status
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

    attendance.mark_filled!
    attendance.mark_sick_leave!
    assert_equal "sick_leave", attendance.status
  end

  test "mark quit only cascades to later started courses" do
    course = courses(:sk_1_course_1)
    later = courses(:sk_1_course_2)
    course.start!
    later.start!
    attendance = attendance_for(course)

    attendance.mark_quit!

    assert_equal "quit", attendance.status
    assert_equal "out", klass_students(:ks_1).reload.status
    assert_equal "quit", attendance_for(later).status
    assert_nil courses(:sk_1_course_3).attendances.find_by(klass_student: klass_students(:ks_1))
  end

  test "mark transfer only cascades to later started courses" do
    course = courses(:sk_1_course_1)
    later = courses(:sk_1_course_2)
    course.start!
    later.start!
    attendance = attendance_for(course)

    attendance.mark_transfer!

    assert_equal "transfer", attendance.status
    assert_equal "transfer", klass_students(:ks_1).reload.status
    assert_equal "transfer", attendance_for(later).status
    assert_nil courses(:sk_1_course_3).attendances.find_by(klass_student: klass_students(:ks_1))
  end

  test "mark rejoin restores the enrollment and started course attendances" do
    course = courses(:sk_1_course_1)
    later = courses(:sk_1_course_2)
    course.start!
    later.start!
    attendance = attendance_for(course)
    attendance.mark_quit!
    assert_equal "quit", attendance_for(later).status

    attendance.mark_rejoin!

    assert_equal "normal", attendance.status
    assert_equal "in", klass_students(:ks_1).reload.status
    assert_equal "normal", attendance_for(later).status
  end

  test "a cascade failure rolls back the quit status and enrollment" do
    course = courses(:sk_1_course_1)
    later = courses(:sk_1_course_2)
    course.start!
    later.start!
    attendance = attendance_for(course)

    original = KlassStudent.method(:active)
    KlassStudent.define_singleton_method(:active) { |*| raise "cascade boom" }
    begin
      assert_raises(RuntimeError) { attendance.mark_quit! }
    ensure
      KlassStudent.define_singleton_method(:active, original)
    end

    assert_equal "normal", attendance.reload.status
    assert_equal "normal", attendance_for(later).status
    assert_equal "in", klass_students(:ks_1).reload.status
  end

  test "mark rejoin releases the transfer target like the class page undo" do
    source = klass_students(:ks_1)
    target_sk = semester_klasses(:sk_eng_1)
    target = KlassStudent.create!(semester_klass: target_sk, student: students(:student_7_1), status: "in")
    course = courses(:sk_1_course_1)
    course.start!
    attendance = attendance_for(course)
    attendance.update!(
      status: "transfer",
      transfer_target_klass_id: target_sk.id
    )
    source.update!(status: :transfer)

    attendance.mark_rejoin!

    assert_equal "normal", attendance.reload.status
    assert_equal "in", source.reload.status
    assert target.reload.archived_at.present?
  end

  test "mark rejoin only restores the trailing leave block" do
    first = courses(:sk_1_course_1)
    second = courses(:sk_1_course_2)
    third = courses(:sk_1_course_3)
    [ first, second, third ].each(&:start!)
    attendance_for(first).mark_quit!

    attendance_for(third).mark_rejoin!

    assert_equal "normal", attendance_for(third).status
    assert_equal "quit", attendance_for(first).status
    assert_equal "quit", attendance_for(second).status
    assert_equal "in", klass_students(:ks_1).reload.status
  end

  test "mark rejoin from a later course still releases the transfer target" do
    source = klass_students(:ks_1)
    target_sk = semester_klasses(:sk_eng_1)
    target = KlassStudent.create!(semester_klass: target_sk, student: students(:student_7_1), status: "in")
    first = courses(:sk_1_course_1)
    second = courses(:sk_1_course_2)
    third = courses(:sk_1_course_3)
    [ first, second, third ].each(&:start!)

    transfer_row = attendance_for(first)
    transfer_row.mark_transfer!
    transfer_row.update!(transfer_target_klass_id: target_sk.id)

    attendance_for(third).mark_rejoin!

    assert_equal "in", source.reload.status
    assert_equal "transfer", attendance_for(first).status
    assert_equal "normal", attendance_for(third).status
    assert_nil attendance_for(first).reload.transfer_target_klass_id
    assert target.reload.archived_at.present?
  end

  test "filled is not allowed from quit or transfer" do
    course = courses(:sk_1_course_1)
    later = courses(:sk_1_course_2)
    course.start!
    later.start!
    attendance = attendance_for(course)

    attendance.mark_quit!
    assert_raises(AASM::InvalidTransition) { attendance.mark_filled! }
    assert_equal "quit", attendance.reload.status

    attendance.mark_rejoin!
    later_attendance = attendance_for(later)
    later_attendance.mark_transfer!
    assert_raises(AASM::InvalidTransition) { later_attendance.mark_filled! }
    assert_equal "transfer", later_attendance.reload.status
  end

  test "personal leave can still be marked quit" do
    course = courses(:sk_1_course_1)
    course.start!
    attendance = attendance_for(course)

    attendance.mark_personal_leave!
    attendance.mark_quit!

    assert_equal "quit", attendance.status
    assert_equal "out", klass_students(:ks_1).reload.status
  end

  test "sick leave can still be marked transfer" do
    course = courses(:sk_1_course_1)
    course.start!
    attendance = attendance_for(course)

    attendance.mark_sick_leave!
    attendance.mark_transfer!

    assert_equal "transfer", attendance.status
    assert_equal "transfer", klass_students(:ks_1).reload.status
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
