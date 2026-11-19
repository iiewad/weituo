class Admin::GradeSubjectsController < AdminController
  before_action :require_admin

  def index
    @grades = Grade.order(:level).to_a
    @subjects = Subject.order(:id).to_a
    @enabled = Current.school.grade_subjects.pluck(:grade_id, :subject_id).map { |grade_id, subject_id| [ grade_id, subject_id ] }
    @class_counts = class_counts_by_combination
  end

  def sync
    selected = normalize_selection(params[:combinations])
    current = Current.school.grade_subjects.pluck(:grade_id, :subject_id).map { |grade_id, subject_id| [ grade_id, subject_id ] }
    used = class_counts_by_combination.keys

    to_add = selected - current
    unused = (current - selected) - used
    blocked = (current - selected) & used

    GradeSubject.transaction do
      to_add.each do |grade_id, subject_id|
        Current.school.grade_subjects.create!(grade_id:, subject_id:)
      end
      unused.each do |grade_id, subject_id|
        Current.school.grade_subjects.where(grade_id:, subject_id:).delete_all
      end
    end

    message = "已更新 #{to_add.size + unused.size} 个年级科目组合"
    message += "，#{blocked.size} 个组合已有班级，未取消" if blocked.any?
    redirect_to admin_grade_subjects_path, notice: message
  end

  private
    def normalize_selection(values)
      grade_ids = Grade.pluck(:id)
      subject_ids = Subject.pluck(:id)

      Array(values).filter_map do |value|
        grade_id, subject_id = value.to_s.split("-").map(&:to_i)
        [ grade_id, subject_id ] if grade_ids.include?(grade_id) && subject_ids.include?(subject_id)
      end.uniq
    end

    def class_counts_by_combination
      SemesterKlass.joins(:semester)
        .where(semesters: { school_id: Current.school.id })
        .group(:grade_id, :subject_id).count
    end
end
