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
