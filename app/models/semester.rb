class Semester < ApplicationRecord
  belongs_to :school
  # get current by current date
  scope :current, -> { where(start_date: ..Date.today).order(:start_date).last }
end
