class Klass < ApplicationRecord
  belongs_to :campuse
  belongs_to :subject
  belongs_to :teacher
  has_many :semester_klasses, dependent: :destroy
  has_many :semesters, through: :semester_klasses
  accepts_nested_attributes_for :semester_klasses, reject_if: :all_blank, allow_destroy: true

  # 确保同一个校区内，科目+班型+序号的组合是唯一的
  validates :seq, uniqueness: {
    scope: [ :campuse_id, :subject_id, :genre ],
    message: "班级信息已存在，不可重复"
  }

  def self.ransackable_attributes(auth_object = nil)
    [ "campuse_id", "genre", "id", "seq", "subject_id", "teacher_id" ]
  end
  
  def self.ransackable_associations(auth_object = nil)
    [ "campuse", "subject", "teacher", "semester_klasses", "semesters" ]
  end

  def name
    "#{subject.name[0]}#{GENRE_MAP_REVERSE[genre][0]}#{seq}"
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