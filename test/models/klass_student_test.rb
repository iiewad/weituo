require "test_helper"

class KlassStudentTest < ActiveSupport::TestCase
  test "starts in and transitions between out and transfer" do
    ks = klass_students(:ks_1)
    assert_equal "in", ks.status

    ks.mark_out!
    assert_equal "out", ks.status

    ks.mark_transfer!
    assert_equal "transfer", ks.status

    ks.mark_out!
    assert_equal "out", ks.status
  end

  test "another semester klasses is scoped to the same campuse and semester" do
    klasses = klass_students(:ks_1).another_semester_klasses(semesters(:semester_previous).id)

    assert_includes klasses, semester_klasses(:sk_math_1)
    assert_equal 1, klasses.count
  end
end
