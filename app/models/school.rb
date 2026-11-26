class School < ApplicationRecord
  validates :name, presence: true

  has_many :campuses
  accepts_nested_attributes_for :campuses, reject_if: :all_blank, allow_destroy: true
  has_many :grade_subjects
  has_many :grades, through: :grade_subjects
  has_many :subjects, through: :grade_subjects
  has_many :user_campuses
  accepts_nested_attributes_for :user_campuses, reject_if: :all_blank, allow_destroy: true
  has_many :semesters
  accepts_nested_attributes_for :semesters, reject_if: :all_blank, allow_destroy: true

  attr_accessor :current_semester_id
  after_save :apply_current_semester

  # has_many :students, through: :campuses
  def history_semesters
    Semester.history(id)
  end

  def current_semester
    Semester.current(id)
  end

  private
    # 每个学校恰好一个当前学期：显式选择优先，否则回落到序号最小的学期
    def apply_current_semester
      if current_semester_id.present? && semesters.exists?(id: current_semester_id)
        semesters.where.not(id: current_semester_id).update_all(current: false)
        semesters.where(id: current_semester_id).update_all(current: true)
      end

      return if semesters.where(current: true).exists?

      semesters.order(:seq).first&.update_column(:current, true)
    end
end
