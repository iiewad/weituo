class School < ApplicationRecord
  validates :name, presence: true

  has_many :campuses
  accepts_nested_attributes_for :campuses, reject_if: :all_blank, allow_destroy: true
  has_many :user_campuses
  accepts_nested_attributes_for :user_campuses, reject_if: :all_blank, allow_destroy: true
end
