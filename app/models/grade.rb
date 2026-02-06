class Grade < ApplicationRecord
  has_many :grade_subjects
  has_many :subjects, through: :grade_subjects
  has_many :semester_klasses
  has_many :klasses, through: :semester_klasses
end
