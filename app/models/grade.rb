class Grade < ApplicationRecord
  has_many :grade_subjects
  has_many :subjects, through: :grade_subjects
  has_many :klasses
end
