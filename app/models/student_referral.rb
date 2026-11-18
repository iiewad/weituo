class StudentReferral < ApplicationRecord
  belongs_to :referrer, class_name: "Student", inverse_of: :given_referrals
  belongs_to :referred, class_name: "Student", inverse_of: :received_referral

  validates :referred_id, uniqueness: true
  validate :referrer_differs_from_referred

  private
    def referrer_differs_from_referred
      return if referrer_id.blank? || referrer_id != referred_id

      errors.add(:referrer_id, "不能是自己")
    end
end
