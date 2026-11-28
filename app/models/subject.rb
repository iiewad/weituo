class Subject < ApplicationRecord
  belongs_to :campuse

  validates :code, presence: true, uniqueness: { scope: :campuse_id }
  validates :name, presence: true, uniqueness: { scope: :campuse_id }

  has_many :teachers
end
