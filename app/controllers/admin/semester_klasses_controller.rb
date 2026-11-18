class Admin::SemesterKlassesController < AdminController
  def export_attendances
    send_data AttendanceWorkbook.new(campuse: Thread.current[:campuse], semester: Thread.current[:semester]).to_xlsx,
      filename: "班级考勤表-#{Thread.current[:semester].name}-#{Thread.current[:campuse].name}.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
  end

  def statement
    @q = SemesterKlass.ransack(params[:q])
    scope = @q.result.joins(:semester, :grade, :subject)
      .includes(:semester, :grade, :subject, :teacher)
      .where(campuse_id: Thread.current[:campuse].id)
      .order("semesters.seq desc, grades.level asc, subjects.name asc, semester_klasses.genre asc, semester_klasses.seq asc")
    report = StatementReport.new(scope, campuse: Thread.current[:campuse])
    @rows = report.rows
    @summary = report.summary
    @semesters = Semester.where(school_id: Thread.current[:school].id)
  end

  def index
    @sks = SemesterKlass.where(
      campuse_id: Thread.current[:campuse].id,
      semester_id: Thread.current[:semester].id,
    ).includes(:grade, :subject, :teacher, :courses).to_a
      .sort_by { |sk| [ sk.grade.level, sk.subject.name, sk.genre, sk.seq ] }
    @active_counts = KlassStudent.where(semester_klass_id: @sks.map(&:id), status: "in").group(:semester_klass_id).count
    @total_courses = @sks.sum { |sk| sk.times.to_i }
    @started_courses = @sks.sum { |sk| sk.courses.count(&:started?) }
    @grade_groups = @sks.group_by(&:grade).sort_by { |grade, _| grade.level }
  end

  def create
    @sk = SemesterKlass.new(semester_klass_params.except(:students_text))
    @sk.subject = @sk.teacher.subject

    if @sk.save
      @sk.add_students_by_text(params[:semester_klass][:students_text])
      redirect_to admin_semester_klass_path(@sk), notice: "班级创建成功"
    else
      redirect_to admin_semester_klasses_path, alert: "班级创建失败，#{@sk.errors.full_messages.join("；")}"
    end
  end

  def update
    @sk = SemesterKlass.where(
      campuse_id: Thread.current[:campuse].id,
    ).find(params[:id])
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
    @sks = @q.result.joins(:semester, :grade, :subject).includes(:semester, :grade, :subject, :teacher, :students, :courses).where(
      campuse_id: Thread.current[:campuse].id,
    ).where(
      "semesters.seq < ?", Thread.current[:semester].seq
    ).order(
      "semesters.seq desc, grades.level asc, subjects.name asc, semester_klasses.genre asc, semester_klasses.seq asc"
    )
    @semesters = Semester.where(
      school_id: Thread.current[:school].id
    ).where(
      "semesters.seq < ?", Thread.current[:semester].seq,
    )
    @active_counts = KlassStudent.where(semester_klass_id: @sks.map(&:id), status: "in").group(:semester_klass_id).count
  end

  def copy_create
    @sk = SemesterKlass.new(semester_klass_params.except(:students_text))
    @sk.semester_id = Thread.current[:semester].id
    @sk.subject = @sk.teacher.subject
    @sk.campuse_id = Thread.current[:campuse].id

    if @sk.save
      @sk.add_students_by_text(semester_klass_params[:students_text])
      redirect_to admin_semester_klass_path(@sk), notice: "复制成功，已生成 #{@sk.name}"
    else
      redirect_to copy_admin_semester_klasses_path(q: params[:q]), alert: "复制失败，#{@sk.errors.full_messages.join("；")}"
    end
  end

  def export_attendance
    @sk = Thread.current[:semester].semester_klasses.find(params[:id])
    send_data AttendanceSheet.new(@sk).to_xlsx,
      filename: "#{@sk.name}-#{@sk.semester.name}-考勤表.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
  end

  def show
    @sk = Thread.current[:semester].semester_klasses.find(params[:id])
    @sks = SemesterKlass.where(
      campuse_id: Thread.current[:campuse].id,
      semester_id: Thread.current[:semester].id,
    ).includes(:grade, :subject, :teacher)
  end

  private
  def semester_klass_params
    params.require(:semester_klass).permit(:campuse_id, :genre, :seq, :times, :teacher_id, :semester_id, :grade_id, :students_text)
  end
end
