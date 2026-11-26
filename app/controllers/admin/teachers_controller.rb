class Admin::TeachersController < AdminController
  def index
    @q = Teacher.ransack(params[:q])
    @subjects = Subject.order(:id)
    @status = params[:status].presence_in(%w[active archived all]) || "active"
    scope = @q.result.includes(:subject, :campuse).where(campuse_id: Current.campuse.id)
    scope = case @status
    when "archived" then scope.archived
    when "all" then scope
    else scope.active
    end
    @teachers = scope.page(params[:page])
  end

  # 存档：教师离职后从开班 / 复制班级的教师选项里隐藏，历史班级和考勤保留
  def archive
    @teacher = Current.campuse.teachers.active.find(params[:id])
    @teacher.archive!
    redirect_to admin_teachers_path(status: params[:status].presence), notice: "#{@teacher.name} 已存档"
  end

  def restore
    @teacher = Current.campuse.teachers.find(params[:id])
    @teacher.restore!
    redirect_to admin_teachers_path(status: params[:status].presence), notice: "#{@teacher.name} 已恢复"
  end

  # 粘贴名单导入教师：每行「科目,姓名,电话」
  def import
    text = params[:teachers_text].to_s
    if text.strip.blank?
      redirect_to admin_teachers_path, alert: "请粘贴教师名单"
      return
    end

    created, skipped = Teacher.add_by_text(Current.campuse.id, text)
    if created.zero?
      redirect_to admin_teachers_path, alert: "没有新增教师，请检查科目名称或教师是否已存在"
    else
      parts = [ "新增 #{created} 名教师" ]
      parts << "跳过 #{skipped} 行（科目不存在或重复）" if skipped.positive?
      redirect_to admin_teachers_path, notice: parts.join("，")
    end
  end

  def create
    @teacher = Teacher.new(teacher_params)
    @teacher.campuse_id = Current.campuse.id

    if @teacher.save
      redirect_to admin_teachers_path, notice: "教师创建成功"
    else
      redirect_to admin_teachers_path, alert: "教师创建失败，#{@teacher.errors.full_messages.join("；")}"
    end
  end

  def update
    @teacher = Teacher.where(campuse_id: Current.campuse.id).find(params[:id])

    if @teacher.update(teacher_params)
      redirect_to admin_teachers_path, notice: "教师更新成功"
    else
      redirect_to admin_teachers_path, alert: "教师更新失败，#{@teacher.errors.full_messages.join("；")}"
    end
  end

  private
    def teacher_params
      params.require(:teacher).permit(:name, :phone, :subject_id)
    end
end
