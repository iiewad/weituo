class Admin::KlassesController < AdminController
  def index
    @klass = Klass.find(params[:klass_id]) if params[:klass_id].present?
    @klasses = Klass.includes(:teacher, :grade, :subject, :semester).where(
      campuse_id: Thread.current[:campuse].id,
      semester_id: Thread.current[:semester].id,
      grade_id: Current.user.grade_ids_by_campuse(Thread.current[:campuse].id)
    )
    @grades = Current.user.grades_by_campuse(Thread.current[:campuse].id).includes(:subjects)
  end

  def show
    @klass = Klass.find(params[:id])
    @klasses = Klass.includes(:teacher, :grade, :subject, :semester).where(
      campuse_id: Thread.current[:campuse].id,
      semester_id: Thread.current[:semester].id,
      grade_id: Current.user.grade_ids_by_campuse(Thread.current[:campuse].id)
    )
    @grades = Current.user.grades_by_campuse(Thread.current[:campuse].id).includes(:subjects)
  end

  def create
    @klass = Klass.new(klass_params.except(:students_text))

    if @klass.save!
      params[:klass][:students_text].split("\n").each do |line|
        line.strip!
        next if line.blank?
        student = Thread.current[:campuse].students.where(grade_id: @klass.grade_id).find_by(name: line)
        next if student.blank?

        @klass.klass_students.create!(student_id: student.id)
      end
      redirect_to admin_klass_path(@klass), notice: "班级创建成功"
    else
      redirect_to admin_klasses_path, notice: "班级创建失败"
    end
  end

  private
    def klass_params
      params.require(:klass).permit(:campuse_id, :semester_id, :genre, :seq, :times, :grade_id, :subject_id, :teacher_id, :students_text)
    end
end
