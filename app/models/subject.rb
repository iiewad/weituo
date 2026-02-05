class Subject < ApplicationRecord
  has_many :teachers
  has_many :klasses
end
