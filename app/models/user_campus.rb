class UserCampus < ApplicationRecord
  belongs_to :user
  belongs_to :campuse
  belongs_to :school
end
