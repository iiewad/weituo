class Semester < ApplicationRecord
  belongs_to :school
  # get current by current date
  scope :current, -> { where(start_date: ..Date.today).order(:start_date).last }
  has_many :semester_klasses, dependent: :destroy
  has_many :klasses, through: :semester_klasses
end
