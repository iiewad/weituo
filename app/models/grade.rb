class Grade < ApplicationRecord
  belongs_to :campuse

  validates :level, presence: true, uniqueness: { scope: :campuse_id }
  validates :name, presence: true, uniqueness: { scope: :campuse_id }

  has_many :grade_subjects
  has_many :subjects, through: :grade_subjects
  has_many :semester_klasses
end
