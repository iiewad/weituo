class Student < ApplicationRecord
  paginates_per 30
  belongs_to :campuse
  belongs_to :grade, optional: true
  has_many :guardians, dependent: :destroy
  accepts_nested_attributes_for :guardians, reject_if: :all_blank, allow_destroy: true

  def self.ransackable_attributes(auth_object = nil)
    [ "birthday", "campuse_id", "created_at", "gender", "grade_id", "id", "in_date", "layer", "name", "phone", "updated_at" ]
  end
end
