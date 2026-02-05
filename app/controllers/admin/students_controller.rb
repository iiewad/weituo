class Admin::StudentsController < AdminController
  def index
    @q = Student.ransack(params[:q])
    @students = @q.result.includes(:grade).where(
      campuse_id: Thread.current[:campuse].id,
      grade_id: Current.user.grade_ids_by_campus_id(Thread.current[:campuse].id)
    ).page(params[:page])
  end

  def create
    @student = Student.new(student_params)
    if @student.save
      redirect_to admin_students_path, notice: "学员创建成功"
    else
      render "admin/students/form"
    end
  end

  def update
    @student = Student.find(params[:id])
    @student.update(student_params)
    redirect_to admin_students_path, notice: "学员信息更新成功"
  end

  private

  def student_params
    params.require(:student).permit(:campuse_id, :name, :phone, :birthday, :grade_id, guardians_attributes: [ :id, :name, :phone, :relationship, :_destroy ])
  end
end
