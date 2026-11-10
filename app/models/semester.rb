class Semester < ApplicationRecord
  belongs_to :school
  def self.current(school_id)
    where(
      "school_id = ? AND start_date <= ? AND end_date >= ?", school_id, Date.today, Date.today
    ).order(:start_date).last
  end

  def self.history(school_id)
    current_semester = current(school_id)
    return none if current_semester.nil?

    where(school_id: school_id).where(seq: ...current_semester.seq).order(seq: :desc)
  end
  has_many :semester_klasses, dependent: :destroy
  has_many :klasses, through: :semester_klasses

  def related_next_semester
    Semester.where(school_id: school_id).where(
      "seq > ?", seq
    ).where(
      "start_date >= ?", end_date
    ).order(seq: :asc).first
  end

  def related_previous_semester
    Semester.where(school_id: school_id).where(seq: ...seq).where(
      "end_date <= ?", start_date
    ).order(seq: :desc).last
  end

  def related_history_semesters
    Semester.where(school_id: school_id).where(
      "seq < ?", seq
    ).where(
      "start_date < ?", start_date
    ).order(seq: :desc)
  end
end