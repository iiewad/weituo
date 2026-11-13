class Admin::TeachersController < AdminController
  def index
    @q = Teacher.ransack(params[:q])
    @teachers = @q.result
      .includes(:subject, :campuse)
      .where(campuse_id: Thread.current[:campuse].id)
      .page(params[:page])
  end

  def create
    @teacher = Teacher.new(teacher_params)
    @teacher.campuse_id = Thread.current[:campuse].id

    if @teacher.save
      redirect_to admin_teachers_path, notice: "教师创建成功"
    else
      redirect_to admin_teachers_path, alert: "教师创建失败，#{@teacher.errors.full_messages.join("；")}"
    end
  end

  def update
    @teacher = Teacher.where(campuse_id: Thread.current[:campuse].id).find(params[:id])

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
