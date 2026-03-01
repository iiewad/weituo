class Semester < ApplicationRecord
  belongs_to :school
  # get current by current date
  scope :current, -> { where(start_date: ..Date.today).order(:start_date).last }
  has_many :semester_klasses, dependent: :destroy
  has_many :klasses, through: :semester_klasses
  # 前一个学期
  def previous
    Semester.where(school_id: school_id, seq: seq - 1).first
  end
end
