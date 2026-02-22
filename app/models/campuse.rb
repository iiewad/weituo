class Campuse < ApplicationRecord
  belongs_to :school
  has_many :user_campuses
  has_many :users, through: :user_campuses
  has_many :students
  has_many :teachers
  has_many :day_schools
  has_many :klasses
end
