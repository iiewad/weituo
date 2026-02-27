class Admin::SemesterKlassesController < AdminController
  def index
    @sks = SemesterKlass.where(
      campuse_id: Thread.current[:campuse].id,
      semester_id: Thread.current[:semester].id,
    )
    @grades = Current.user.grades_by_campuse(Thread.current[:campuse].id).includes(:subjects)
  end
  
  def create
    @sk = SemesterKlass.new(semester_klass_params.except(:students_text))
    @sk.subject = @sk.teacher.subject

    if @sk.save
      @sk.add_students_by_text(params[:semester_klass][:students_text])
      redirect_to admin_semester_klass_path(sk), notice: "班级创建成功"
    else
      redirect_to admin_semester_klasses_path, alert: "班级创建失败，#{@sk.errors.full_messages.join("；")}"
    end
  end

  def update
    @sk = SemesterKlass.find(params[:id])
    teacher = Teacher.find(params[:semester_klass][:teacher_id])
    if @sk.update(semester_klass_params.except(:students_text).merge(subject_id: teacher.subject_id))
      @sk.add_students_by_text(params[:semester_klass][:students_text])
      redirect_to admin_semester_klass_path(@sk), notice: "班级更新成功"
    else
      redirect_to admin_semester_klasses_path, alert: "班级更新失败，#{@sk.errors.full_messages.join("；")}"
    end
  end
    

  def copy
    @q = SemesterKlass.ransack(params[:q])
    @sks = @q.result.includes(:klass).where.not(
      semester_id: Thread.current[:semester].id,
    )
    @cp_sk = nil
    @cp_sk = @sks.find(params[:cp_sk_id]) if params[:cp_sk_id].present?
  end

  def copy_create
    @sk = SemesterKlass.new(semester_klass_params.except(:students_text))
    if @sk.save
      @sk.add_students_by_text(semester_klass_params[:students_text])
      redirect_to copy_admin_semester_klasses_path(
        cp_sk_id: @sk.id,
        q: params[:q],
      ), notice: "复制成功"
    else
      render :copy, alert: "复制失败"
    end
  end

  def show
    @sk = Thread.current[:semester].semester_klasses.find(params[:id])
    @sks = SemesterKlass.where(
      campuse_id: Thread.current[:campuse].id,
      semester_id: Thread.current[:semester].id,
    )
    @grades = Current.user.grades_by_campuse(Thread.current[:campuse].id).includes(:subjects)
  end

  private
  def semester_klass_params
    params.require(:semester_klass).permit(:campuse_id, :genre, :seq, :times, :teacher_id, :semester_id, :grade_id, :students_text)
  end
end
