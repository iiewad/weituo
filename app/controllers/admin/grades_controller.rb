class Admin::GradesController < AdminController
  before_action :require_admin

  def create
    grade = Current.campuse.grades.new(grade_params)

    if grade.save
      grant_grade_to_campus_admins(grade)
      redirect_to admin_grade_subjects_path, notice: "年级已添加"
    else
      redirect_to admin_grade_subjects_path, alert: "年级添加失败，#{grade.errors.full_messages.join("；")}"
    end
  end

  def update
    grade = Current.campuse.grades.find(params[:id])

    if grade.update(grade_params)
      redirect_to admin_grade_subjects_path, notice: "年级已更新"
    else
      redirect_to admin_grade_subjects_path, alert: "年级更新失败，#{grade.errors.full_messages.join("；")}"
    end
  end

  def destroy
    grade = Current.campuse.grades.find(params[:id])
    blockers = []

    blockers << "学员" if Student.exists?(grade_id: grade.id)
    blockers << "班级" if SemesterKlass.exists?(grade_id: grade.id)
    blockers << "年级科目组合" if GradeSubject.exists?(grade_id: grade.id)
    blockers << "用户授权" if UserCampuse.where(campuse_id: Current.campuse.id).any? { |user_campuse| Array(user_campuse.grade_ids).include?(grade.id) }

    if blockers.any?
      redirect_to admin_grade_subjects_path, alert: "该年级已被#{blockers.join("、")}使用，不能删除"
      return
    end

    grade.destroy
    redirect_to admin_grade_subjects_path, notice: "年级已删除"
  end

  private
    # 新建年级自动追加进本校区所有超级管理员的授权年级，
    # 否则新校区（授权 grade_ids 为空）建完年级后列表页仍然全空
    def grant_grade_to_campus_admins(grade)
      UserCampuse.where(campuse_id: Current.campuse.id, role: "admin").find_each do |user_campuse|
        next if Array(user_campuse.grade_ids).include?(grade.id)

        user_campuse.update!(grade_ids: Array(user_campuse.grade_ids) + [ grade.id ])
      end
    end

    def grade_params
      params.require(:grade).permit(:level, :name)
    end
end
