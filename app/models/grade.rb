class Grade < ApplicationRecord
  validates :level, presence: true, uniqueness: true
  validates :name, presence: true, uniqueness: true

  has_many :grade_subjects
  has_many :subjects, through: :grade_subjects
  has_many :semester_klasses
end
