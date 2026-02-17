class Student < ApplicationRecord
  paginates_per 30
  belongs_to :day_school, optional: true
  belongs_to :campuse
  belongs_to :grade, optional: true
  has_many :guardians, dependent: :destroy
  has_many :klass_students, dependent: :destroy
  has_many :klasses, through: :klass_students
  accepts_nested_attributes_for :guardians, reject_if: :all_blank, allow_destroy: true

  def self.ransackable_attributes(auth_object = nil)
    [ "name" ]
  end
end
