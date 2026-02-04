class School < ApplicationRecord
  has_many :campuses
  accepts_nested_attributes_for :campuses, reject_if: :all_blank, allow_destroy: true
  has_many :grade_subjects
  has_many :grades, through: :grade_subjects
  has_many :subjects, through: :grade_subjects
  accepts_nested_attributes_for :grade_subjects, reject_if: :all_blank, allow_destroy: true
  has_many :semesters
  accepts_nested_attributes_for :semesters, reject_if: :all_blank, allow_destroy: true
end
