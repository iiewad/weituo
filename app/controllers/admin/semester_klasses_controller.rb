class Admin::SemesterKlassesController < AdminController
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
      semester_klass_params[:students_text].split("\n").each do |line|
        line.strip!
        next if line.blank?
        student = Thread.current[:campuse].students.where(grade_id: @sk.grade_id).find_by(name: line)
        next if student.blank?

        @sk.klass_students.create!(student_id: student.id)
      end
      redirect_to copy_admin_semester_klasses_path(
        cp_sk_id: @sk.id,
        q: params[:q],
      ), notice: "复制成功"
    else
      render :copy
    end
  end
  def show
    @sk = SemesterKlass.find(params[:id])
    @klass = @sk.klass
    @sks = SemesterKlass.includes(:klass).where(
      klasses: { campuse_id: Thread.current[:campuse].id },
      semester_id: Thread.current[:semester].id,
    )
    @klasses =  Klass.where(
      id: @sks.map(&:klass_id)
    )
    @grades = Current.user.grades_by_campuse(Thread.current[:campuse].id).includes(:subjects)
  end

  private
  def semester_klass_params
    params.require(:semester_klass).permit(:semester_id, :klass_id, :grade_id, :times, :students_text)
  end
end
