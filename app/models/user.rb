class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :user_campuses, dependent: :destroy
  has_many :campuses, through: :user_campuses
  accepts_nested_attributes_for :user_campuses, allow_destroy: true,
    reject_if: ->(attributes) { attributes["campuse_id"].blank? }
  # normalizes :email_address, with: ->(e) { e.strip.downcase }
  def subjects_by_campuse(campuse_id)
    campuse = Campuse.find(campuse_id)
    Subject.where(id: campuse.grade_subjects.select(:subject_id))
  end

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
