class GradeSubject < ApplicationRecord
  belongs_to :campuse
  belongs_to :semester
  belongs_to :grade
  belongs_to :subject

  validates :times, numericality: { only_integer: true, greater_than: 0 }
  validates :grade_id, uniqueness: { scope: [ :campuse_id, :semester_id, :subject_id ] }
  validate :associations_share_campuse

  def name
    "#{grade.name} #{subject.name}"
  end

  private
    def associations_share_campuse
      return if campuse.blank?

      if semester.present? && semester.campuse_id != campuse_id
        errors.add(:semester_id, "与校区不一致")
      end
      if grade.present? && grade.campuse_id != campuse_id
        errors.add(:grade_id, "与校区不一致")
      end
      if subject.present? && subject.campuse_id != campuse_id
        errors.add(:subject_id, "与校区不一致")
      end
    end
end
