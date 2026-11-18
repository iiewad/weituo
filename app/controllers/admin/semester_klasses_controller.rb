class Admin::SemesterKlassesController < AdminController
  def export_attendances
    send_data AttendanceWorkbook.new(campuse: Thread.current[:campuse], semester: Thread.current[:semester]).to_xlsx,
      filename: "班级考勤表-#{Thread.current[:semester].name}-#{Thread.current[:campuse].name}.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
  end

  def statement
    @q = SemesterKlass.ransack(params[:q])
    report = StatementReport.new(statement_scope, campuse: Thread.current[:campuse])
    @rows = report.rows
    @summary = report.summary
    @semesters = Semester.where(school_id: Thread.current[:school].id)
  end

  def export_statement
    @q = SemesterKlass.ransack(params[:q])
    report = StatementReport.new(statement_scope, campuse: Thread.current[:campuse])

    send_data StatementSheet.new(
      rows: report.rows,
      summary: report.summary,
      campuse: Thread.current[:campuse],
      semester: Thread.current[:semester],
      filter_summary: statement_filter_summary
    ).to_xlsx,
      filename: "班级报表-#{Thread.current[:semester].name}-#{Thread.current[:campuse].name}.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
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
    @new_class_candidates = new_class_candidates
  end

  def create
    @sk = SemesterKlass.new(semester_klass_params.except(:students_text))
    @sk.subject = @sk.teacher.subject

    if @sk.save
      apply_students(@sk)
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
      apply_students(@sk)
      redirect_to admin_semester_klass_path(@sk), notice: "班级更新成功"
    else
      redirect_to admin_semester_klasses_path, alert: "班级更新失败，#{@sk.errors.full_messages.join("；")}"
    end
  end

  def copy
    @target_semester = copy_target_semester
    @target_semesters = copy_target_semesters
    @q = SemesterKlass.ransack(params[:q])
    @sks = @q.result.joins(:semester, :grade, :subject).includes(:semester, :grade, :subject, :teacher, :students, :courses, klass_students: :student).where(
      campuse_id: Thread.current[:campuse].id,
    ).where(
      "semesters.seq < ?", @target_semester.seq
    ).order(
      "semesters.seq desc, grades.level asc, subjects.name asc, semester_klasses.genre asc, semester_klasses.seq asc"
    )
    @semesters = Semester.where(
      school_id: Thread.current[:school].id
    ).where(
      "semesters.seq < ?", @target_semester.seq,
    )
    @active_counts = KlassStudent.where(semester_klass_id: @sks.map(&:id), status: "in").group(:semester_klass_id).count
    @students_by_grade = Student.where(campuse_id: Thread.current[:campuse].id, grade_id: @sks.map(&:grade_id).uniq)
      .order(:name)
      .group_by(&:grade_id)
  end

  def copy_create
    target_semester = copy_target_semester
    @sk = SemesterKlass.new(semester_klass_params.except(:students_text))
    @sk.semester_id = target_semester.id
    @sk.subject = @sk.teacher.subject
    @sk.campuse_id = Thread.current[:campuse].id

    if @sk.save
      student_ids = Array(params[:student_ids]).reject(&:blank?)
      Student.where(id: student_ids, campuse_id: @sk.campuse_id, grade_id: @sk.grade_id).find_each do |student|
        student.join_klass(@sk, course_seq: 1)
      end

      if target_semester == Thread.current[:semester]
        redirect_to admin_semester_klass_path(@sk), notice: "复制成功，已生成 #{@sk.name}"
      else
        redirect_to copy_admin_semester_klasses_path(target_semester_id: target_semester.id),
          notice: "复制成功，已在 #{target_semester.name} 生成 #{@sk.name}"
      end
    else
      redirect_to copy_admin_semester_klasses_path(target_semester_id: target_semester.id, q: params[:q]),
        alert: "复制失败，#{@sk.errors.full_messages.join("；")}"
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
    @insert_student_candidates = Student.where(
      campuse_id: Thread.current[:campuse].id,
      grade_id: @sk.grade_id
    ).where.not(id: @sk.klass_students.select(:student_id)).order(:name)
    @new_class_candidates = new_class_candidates
  end

  private
  def new_class_candidates
    Student.where(
      campuse_id: Thread.current[:campuse].id,
      grade_id: Current.user.grades_by_campuse(Thread.current[:campuse].id).ids
    ).includes(:grade).order(:name)
  end

  def apply_students(semester_klass)
    student_ids = Array(params[:student_ids]).reject(&:blank?)

    if student_ids.any?
      max_seq = [ semester_klass.times.to_i, 1 ].max
      join_seq = [ [ params[:join_course_seq].to_i, 1 ].max, max_seq ].min
      Student.where(id: student_ids, campuse_id: semester_klass.campuse_id, grade_id: semester_klass.grade_id)
        .where.not(id: semester_klass.klass_students.select(:student_id))
        .find_each { |student| student.join_klass(semester_klass, course_seq: join_seq) }
    elsif params.dig(:semester_klass, :students_text).present?
      semester_klass.add_students_by_text(params[:semester_klass][:students_text])
    end
  end

  # 目标学期只能选当前学期及其之后的学期；默认当前学期
  def copy_target_semester
    return Thread.current[:semester] if params[:target_semester_id].blank?

    Semester.where(school_id: Thread.current[:school].id)
      .where("seq >= ?", Thread.current[:semester].seq)
      .find_by(id: params[:target_semester_id]) || Thread.current[:semester]
  end

  def copy_target_semesters
    Semester.where(school_id: Thread.current[:school].id)
      .where("seq >= ?", Thread.current[:semester].seq)
      .order(:seq, :id)
  end

  def statement_scope
    @q.result.joins(:semester, :grade, :subject)
      .includes(:semester, :grade, :subject, :teacher)
      .where(campuse_id: Thread.current[:campuse].id)
      .order("semesters.seq desc, grades.level asc, subjects.name asc, semester_klasses.genre asc, semester_klasses.seq asc")
  end

  def statement_filter_summary
    filters = params[:q] || {}
    parts = []
    if filters[:semester_id_eq].present?
      parts << "学期：#{Semester.find_by(id: filters[:semester_id_eq])&.name}"
    end
    if filters[:grade_id_eq].present?
      parts << "年级：#{Grade.find_by(id: filters[:grade_id_eq])&.name}"
    end
    if filters[:subject_id_eq].present?
      parts << "科目：#{Subject.find_by(id: filters[:subject_id_eq])&.name}"
    end
    if filters[:teacher_id_eq].present?
      parts << "教师：#{Teacher.find_by(id: filters[:teacher_id_eq])&.name}"
    end
    if filters[:genre_eq].present?
      parts << "班型：#{SemesterKlass::GENRE_MAP_REVERSE[filters[:genre_eq]] || filters[:genre_eq]}"
    end

    parts.presence&.join(" · ") || "全部班级"
  end

  def semester_klass_params
    params.require(:semester_klass).permit(:campuse_id, :genre, :seq, :times, :teacher_id, :semester_id, :grade_id, :students_text)
  end
end
