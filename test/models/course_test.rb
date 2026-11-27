require "test_helper"

class CourseTest < ActiveSupport::TestCase
  test "fixtures init" do
    assert_equal 64, courses.count
  end

  test "course start" do
    course = courses(:sk_1_course_1)
    course.start!
    assert_equal true, course.started?
  end

  test "start creates an attendance for every enrolled student" do
    course = courses(:sk_1_course_1)

    assert_difference -> { course.attendances.count }, 1 do
      course.start!
    end
    assert_equal "normal", course.attendances.find_by!(klass_student_id: klass_students(:ks_1).id).status
    assert_equal Date.today, course.reload.start_date
  end

  test "start is idempotent" do
    course = courses(:sk_1_course_1)
    assert course.start!
    started_on = course.reload.start_date

    assert_no_difference -> { course.attendances.count } do
      assert_not course.start!
    end
    assert_equal started_on, course.reload.start_date
  end

  test "cannot start a later course before earlier ones" do
    sk = semester_klasses(:sk_math_1)
    second = sk.courses.find_by!(seq: 2)

    assert_not second.start!
    assert_not second.reload.started?
    assert_empty second.attendances
  end

  test "starts courses in order" do
    sk = semester_klasses(:sk_math_1)
    first = sk.courses.find_by!(seq: 1)
    second = sk.courses.find_by!(seq: 2)

    assert first.start!
    assert second.start!
    assert second.reload.started?
  end

  test "start keeps quit status for a student who left the class" do
    course = courses(:sk_1_course_1)
    klass_students(:ks_1).mark_out!

    assert_difference -> { course.attendances.count }, 1 do
      course.start!
    end
    assert_equal "quit", course.attendances.find_by!(klass_student_id: klass_students(:ks_1).id).status
    assert_includes semester_klasses(:sk_math_1).klass_students, klass_students(:ks_1)
  end

  test "start keeps transfer status for a transferred student" do
    course = courses(:sk_1_course_1)
    klass_students(:ks_1).mark_transfer!

    course.start!

    assert_equal "transfer", course.attendances.find_by!(klass_student_id: klass_students(:ks_1).id).status
  end

  test "start marks a transferred-in student's pre-entry courses as transfer_in" do
    sk = semester_klasses(:sk_math_1)
    ks = klass_students(:ks_1)
    ks.update!(transfer_source_klass: semester_klasses(:sk_math_2), transfer_in_seq: 3)

    [ 1, 2, 3 ].each { |seq| assert sk.courses.find_by!(seq: seq).start! }

    assert_equal "transfer_in", sk.courses.find_by!(seq: 1).attendances.find_by!(klass_student_id: ks.id).status
    assert_equal "transfer_in", sk.courses.find_by!(seq: 2).attendances.find_by!(klass_student_id: ks.id).status
    assert_equal "normal", sk.courses.find_by!(seq: 3).attendances.find_by!(klass_student_id: ks.id).status
  end

  test "start does not overwrite an existing pre-entry attendance row of a transferred-in student" do
    sk = semester_klasses(:sk_math_1)
    ks = klass_students(:ks_1)
    ks.update!(transfer_source_klass: semester_klasses(:sk_math_2), transfer_in_seq: 3)
    first = sk.courses.find_by!(seq: 1)
    first.attendances.create!(klass_student: ks, status: "absent")

    assert first.start!

    assert_equal "absent", first.attendances.find_by!(klass_student_id: ks.id).status
  end
end
