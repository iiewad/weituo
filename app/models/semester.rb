class Semester < ApplicationRecord
  belongs_to :school

  validates :name, :seq, presence: true
  validates :seq, uniqueness: { scope: :school_id }

  # 当前学期由 semesters.current 标记决定（每个学校唯一），不再根据日期推断
  def self.current(school_id)
    where(school_id: school_id, current: true).first
  end

  def self.history(school_id)
    current_semester = current(school_id)
    return none if current_semester.nil?

    where(school_id: school_id).where(seq: ...current_semester.seq).order(seq: :desc)
  end
  has_many :semester_klasses, dependent: :destroy
  # 学期删除后预留记录失去目标，一并删除，否则外键会拦住学校表单里的学期删除
  has_many :reservations, dependent: :destroy
  # 学员的入学学期；学期删除时置空，不删学员
  has_many :students, class_name: "Student", foreign_key: :in_semester_id, dependent: :nullify, inverse_of: :in_semester

  def self.ransackable_attributes(auth_object = nil)
    [ "id", "name", "seq" ]
  end

  # 学期顺序统一以 seq 为准
  def related_next_semester
    Semester.where(school_id: school_id).where("seq > ?", seq).order(seq: :asc).first
  end

  def related_previous_semester
    Semester.where(school_id: school_id).where("seq < ?", seq).order(seq: :desc).first
  end

  def related_history_semesters
    Semester.where(school_id: school_id).where("seq < ?", seq).order(seq: :desc)
  end
end
