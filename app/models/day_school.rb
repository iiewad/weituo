class DaySchool < ApplicationRecord
  belongs_to :campuse
  has_many :students

  validates :name, presence: true,
    uniqueness: { scope: :campuse_id, message: "在当前校区已存在" }

  def self.add_by_text(campuse_id, str)
    campuse = Campuse.find(campuse_id)
    str.split("\n").each do |line|
      name = line.strip
      day_school = DaySchool.find_or_create_by(name: name, campuse_id: campuse_id)
    end
  end
end
