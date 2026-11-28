class Admin::GradeSubjectsController < AdminController
  before_action :require_admin

  def index
    @grades = Current.campuse.grades.order(:level).to_a
    @subjects = Current.campuse.subjects.order(:id).to_a
    @grade_subjects = current_grade_subjects
    @enabled = @grade_subjects.pluck(:grade_id, :subject_id)
    @times_by_combination = @grade_subjects.pluck(:grade_id, :subject_id, :times)
      .to_h { |grade_id, subject_id, times| [ "#{grade_id}-#{subject_id}", times ] }
    @class_counts = class_counts_by_combination
  end

  def sync
    selected = normalize_selection(params[:combinations])
    current = current_grade_subjects.pluck(:grade_id, :subject_id)
    used = class_counts_by_combination.keys

    to_add = selected - current
    unused = (current - selected) - used
    blocked = (current - selected) & used

    GradeSubject.transaction do
      to_add.each do |grade_id, subject_id|
        Current.campuse.grade_subjects.create!(
          semester_id: Current.semester.id,
          grade_id: grade_id,
          subject_id: subject_id,
          times: submitted_times(grade_id, subject_id) || 16
        )
      end

      (selected & current).each do |grade_id, subject_id|
        times = submitted_times(grade_id, subject_id)
        next unless times

        current_grade_subjects.find_by(grade_id: grade_id, subject_id: subject_id).update!(times: times)
      end

      unused.each do |grade_id, subject_id|
        current_grade_subjects.where(grade_id: grade_id, subject_id: subject_id).delete_all
      end
    end

    message = "已更新 #{to_add.size + unused.size} 个年级科目组合"
    message += "，#{blocked.size} 个组合已有班级，未取消" if blocked.any?
    redirect_to admin_grade_subjects_path, notice: message
  end

  private
    def current_grade_subjects
      Current.campuse.grade_subjects.where(semester_id: Current.semester.id)
    end

    def normalize_selection(values)
      grade_ids = Current.campuse.grades.pluck(:id)
      subject_ids = Current.campuse.subjects.pluck(:id)

      Array(values).filter_map do |value|
        grade_id, subject_id = value.to_s.split("-").map(&:to_i)
        [ grade_id, subject_id ] if grade_ids.include?(grade_id) && subject_ids.include?(subject_id)
      end.uniq
    end

    def submitted_times(grade_id, subject_id)
      value = params.dig(:times, "#{grade_id}-#{subject_id}").to_s.strip
      return nil if value.blank?

      times = value.to_i
      times.positive? ? times : nil
    end

    def class_counts_by_combination
      SemesterKlass.where(semester_id: Current.semester.id)
        .group(:grade_id, :subject_id).count
    end
end
