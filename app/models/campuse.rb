class Campuse < ApplicationRecord
  belongs_to :school
  has_many :user_campuses
  has_many :users, through: :user_campuses
  has_many :students
  has_many :teachers
  has_many :day_schools
  has_many :semester_klasses

  validates :reserve_min_attendances, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
