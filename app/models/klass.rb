class Klass < ApplicationRecord
  belongs_to :campuse
  belongs_to :subject
  belongs_to :teacher
  has_many :klass_students, dependent: :destroy
  has_many :students, through: :klass_students
  has_many :courses, dependent: :destroy
  has_many :semester_klasses, dependent: :destroy
  has_many :semesters, through: :semester_klasses
  accepts_nested_attributes_for :semester_klasses, reject_if: :all_blank, allow_destroy: true

  def self.ransackable_attributes(auth_object = nil)
    [ "campuse_id", "genre", "id", "seq", "subject_id", "teacher_id" ]
  end
  def self.ransackable_attributes(auth_object = nil)
    [ "campuse_id", "genre", "id", "seq", "subject_id", "teacher_id" ]
  end


  GENRE_MAP = {
    "提高班" => "TG",
    "精英班" => "JY",
    "创新班" => "XZ",
    "兴趣班" => "XQ",
    "超常班" => "CC"
  }

  GENRE_MAP_REVERSE = GENRE_MAP.invert
end
