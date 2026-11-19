class GradeSubject < ApplicationRecord
  belongs_to :school
  belongs_to :semester
  belongs_to :grade
  belongs_to :subject

  validates :times, numericality: { only_integer: true, greater_than: 0 }
  validates :grade_id, uniqueness: { scope: [ :school_id, :semester_id, :subject_id ] }
  validate :semester_belongs_to_school

  def name
    "#{grade.name} #{subject.name}"
  end

  private
    def semester_belongs_to_school
      return if semester.blank? || school.blank? || semester.school_id == school_id

      errors.add(:semester_id, "与学校不一致")
    end
end
