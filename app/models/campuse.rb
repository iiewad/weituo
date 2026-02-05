class Campuse < ApplicationRecord
  belongs_to :school
  has_many :user_campuses
  has_many :users, through: :user_campuses
  has_many :students
end
