class Admin::GradesController < AdminController
  before_action :require_admin

  def create
    grade = Grade.new(grade_params)

    if grade.save
      redirect_to admin_grade_subjects_path, notice: "年级已添加"
    else
      redirect_to admin_grade_subjects_path, alert: "年级添加失败，#{grade.errors.full_messages.join("；")}"
    end
  end

  def update
    grade = Grade.find(params[:id])

    if grade.update(grade_params)
      redirect_to admin_grade_subjects_path, notice: "年级已更新"
    else
      redirect_to admin_grade_subjects_path, alert: "年级更新失败，#{grade.errors.full_messages.join("；")}"
    end
  end

  def destroy
    grade = Grade.find(params[:id])
    blockers = []

    blockers << "学员" if Student.exists?(grade_id: grade.id)
    blockers << "班级" if SemesterKlass.exists?(grade_id: grade.id)
    blockers << "年级科目组合" if GradeSubject.exists?(grade_id: grade.id)
    blockers << "用户授权" if UserCampuse.all.any? { |user_campuse| Array(user_campuse.grade_ids).include?(grade.id) }

    if blockers.any?
      redirect_to admin_grade_subjects_path, alert: "该年级已被#{blockers.join("、")}使用，不能删除"
      return
    end

    grade.destroy
    redirect_to admin_grade_subjects_path, notice: "年级已删除"
  end

  private
    def grade_params
      params.require(:grade).permit(:level, :name)
    end
end
