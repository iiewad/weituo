class Admin::StudentsController < AdminController
  def index
    @q = Student.ransack(params[:q])
    @students = @q.result.includes(:grade).where(
      campuse_id: Thread.current[:campuse].id,
      grade_id: Current.user.grade_ids_by_campuse(Thread.current[:campuse].id)
    ).page(params[:page])
    if params[:filter].present?
      ks = KlassStudent.includes(:semester_klass).where(
        semester_klasses: {
          semester_id: Thread.current[:semester].id
        }
      )
      if params[:filter] == "in_class"
        @students = @students.where(id: ks.where(status: "in").pluck(:student_id))
      elsif params[:filter] == "out_class"
        @students = @students.where(id: ks.where(status: "out").pluck(:student_id))
      elsif params[:filter] == "not_in_class"
        @students = @students.where.not(id: ks.where(status: %w[in out]).pluck(:student_id))
      end
    end
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
    params.require(:student).permit(:campuse_id, :day_school_id, :name, :phone, :layer, :birthday, :grade_id, guardians_attributes: [ :id, :name, :phone, :relationship, :_destroy ])
  end
end
