class School < ApplicationRecord
  has_many :campuses
  accepts_nested_attributes_for :campuses, reject_if: :all_blank, allow_destroy: true
end
