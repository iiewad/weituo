require "test_helper"

class StudentReferralTest < ActiveSupport::TestCase
  test "referred student can only have one referrer" do
    duplicate = StudentReferral.new(referrer: students(:student_9_2), referred: students(:student_7_1))

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:referred_id], "has already been taken"
  end

  test "student cannot refer themselves" do
    referral = StudentReferral.new(referrer: students(:student_7_2), referred: students(:student_7_2))

    assert_not referral.valid?
    assert_includes referral.errors[:referrer_id], "不能是自己"
  end
end
