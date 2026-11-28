class Admin::SubjectsController < AdminController
  before_action :require_admin

  def create
    subject = Current.campuse.subjects.new(subject_params)

    if subject.save
      redirect_to admin_grade_subjects_path, notice: "科目已添加"
    else
      redirect_to admin_grade_subjects_path, alert: "科目添加失败，#{subject.errors.full_messages.join("；")}"
    end
  end

  def update
    subject = Current.campuse.subjects.find(params[:id])

    if subject.update(subject_params)
      redirect_to admin_grade_subjects_path, notice: "科目已更新"
    else
      redirect_to admin_grade_subjects_path, alert: "科目更新失败，#{subject.errors.full_messages.join("；")}"
    end
  end

  def destroy
    subject = Current.campuse.subjects.find(params[:id])
    blockers = []

    blockers << "教师" if Teacher.exists?(subject_id: subject.id)
    blockers << "班级" if SemesterKlass.exists?(subject_id: subject.id)
    blockers << "年级科目组合" if GradeSubject.exists?(subject_id: subject.id)

    if blockers.any?
      redirect_to admin_grade_subjects_path, alert: "该科目已被#{blockers.join("、")}使用，不能删除"
      return
    end

    subject.destroy
    redirect_to admin_grade_subjects_path, notice: "科目已删除"
  end

  private
    def subject_params
      params.require(:subject).permit(:code, :name)
    end
end
