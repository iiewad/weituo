class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :user_campuses
  has_many :campuses, through: :user_campuses
  # normalizes :email_address, with: ->(e) { e.strip.downcase }

  def grade_ids_by_campuse(campuse_id)
    user_campuses.where(campuse_id: campuse_id).pluck(:grade_ids).flatten
  end

  def grades_by_campuse(campuse_id)
    Grade.where(
      id: grade_ids_by_campuse(campuse_id)
    )
  end

  def has_role_by_campuse_id(campuse_id, role)
    user_campuses.where(campuse_id:).collect(&:role).include?(role)
  end
end
