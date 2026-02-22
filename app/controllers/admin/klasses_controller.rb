class Admin::KlassesController < AdminController
  def index
    @q = Thread.current[:campuse].klasses.joins(:semester_klasses).where(
      semester_klasses: { grade_id: Current.user.grade_ids_by_campuse(Thread.current[:campuse].id) }
    ).ransack(params[:q])
    @klasses = @q.result(distinct: true)
    @klass_subjects = Thread.current[:school].subjects.includes(:teachers).uniq
    @menu_hash = []
    @klass_subjects.each do |subject|
      Klass::GENRE_MAP.values.each do |kg|
        sks = SemesterKlass.joins(:klass).where(
          klasses: { genre: kg, subject_id: subject.id }
        )
        klasses = sks.includes(:klass).map(&:klass)
        teachers = klasses.map(&:teacher).uniq
        @menu_hash << {
        s_n: subject.name,
        s_id: subject.id,
        k_g: kg,
        teachers: teachers.map { |teacher| { id: teacher.id, name: teacher.name } }
      }
      end
    end
  end

  def show
    @klass = Klass.find(params[:id])
    @klasses = Klass.includes(:teacher, :grade, :subject, :semester_klasses, courses: :attendances).where(
      semester_klasses: { semester_id: Thread.current[:semester].id },
      campuse_id: Thread.current[:campuse].id,
      grade_id: Current.user.grade_ids_by_campuse(Thread.current[:campuse].id)
    )
    @grades = Current.user.grades_by_campuse(Thread.current[:campuse].id).includes(:subjects)
  end

  def create
    teacher = Teacher.find(params[:klass][:teacher_id])
    @klass = Klass.new(klass_params.except(:students_text).merge(subject_id: teacher.subject_id))

    if @klass.save!
      sk = @klass.semester_klasses.find_by!(semester_id: Thread.current[:semester].id)
      sk.add_students_by_text(params[:klass][:students_text])
      redirect_to admin_semester_klass_path(sk), notice: "班级创建成功"
    else
      redirect_to admin_semester_klasses_path, alert: "班级创建失败"
    end
  end

  def update
    @klass = Klass.find(params[:id])
    teacher = Teacher.find(params[:klass][:teacher_id])
    if @klass.update(klass_params.except(:students_text).merge(subject_id: teacher.subject_id))
      sk = @klass.semester_klasses.find_by!(semester_id: Thread.current[:semester].id)
      sk.add_students_by_text(params[:klass][:students_text])
      redirect_to admin_semester_klass_path(sk), notice: "班级更新成功"
    else
      redirect_to admin_semester_klasses_path, alert: "班级更新失败"
    end
  end

  private
    def klass_params
      params.require(:klass).permit(:campuse_id, :genre, :seq, :teacher_id, :students_text, semester_klasses_attributes: [ :id, :semester_id, :grade_id, :times, :_destroy ])
    end
end