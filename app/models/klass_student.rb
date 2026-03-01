class KlassStudent < ApplicationRecord
  include AASM

  belongs_to :semester_klass
  belongs_to :student
  has_many :attendances, dependent: :destroy

  enum :status, [ :out, :in ]

  aasm column: :status, enum: true do
    state :in, initial: true
    state :out

    event :mark_out do
      transitions from: :in, to: :out
    end
  end

  def another_semester_klasses(semester_id)
    SemesterKlass
      .joins(:klass_students)
      .where(
        semester_id: semester_id,
        campuse_id: semester_klass.campuse_id,
      )
  end

  def reserved2?
    return false if semester_klass.semester.previous.previous.blank?
    another_semester_klasses(semester_klass.semester.previous.previous.id)
      .where(
        subject_id: semester_klass.subject_id,
      )
      .exists?(
        klass_students: { student_id: student_id, status: :in }
      )
  end

  # 前一个学期在相同学科的班级则为reserved
  def reserved?
    return false if semester_klass.semester.previous.blank?
    another_semester_klasses(semester_klass.semester.previous.id)
      .where(
        subject_id: semester_klass.subject_id,
      )
      .exists?(
        klass_students: { student_id: student_id, status: :in }
      )
  end

  # 前一个学期有就读单非相同科目的班级则为expand
  def expand?
    return false if semester_klass.semester.previous.blank?
    
    is_present = another_semester_klasses(semester_klass.semester.previous.id)
      .where.not(
        subject_id: semester_klass.subject_id,
      )
      .exists?(
        klass_students: { student_id: student_id }
      )
  end
end