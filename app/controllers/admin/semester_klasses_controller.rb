class Admin::SemesterKlassesController < AdminController
  def export_attendances
    send_data AttendanceWorkbook.new(
      campuse: Current.campuse,
      semester: Current.semester,
      grade_ids: allowed_grade_ids
    ).to_xlsx,
      filename: "班级考勤表-#{Current.semester.name}-#{Current.campuse.name}.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
  end

  def statement
    @q = SemesterKlass.ransack(params[:q])
    report = StatementReport.new(statement_scope, campuse: Current.campuse)
    @rows = report.rows
    @summary = report.summary
    @semesters = Semester.where(school_id: Current.school.id)
  end

  def export_statement
    @q = SemesterKlass.ransack(params[:q])
    report = StatementReport.new(statement_scope, campuse: Current.campuse)

    send_data StatementSheet.new(
      rows: report.rows,
      summary: report.summary,
      campuse: Current.campuse,
      semester: Current.semester,
      filter_summary: statement_filter_summary
    ).to_xlsx,
      filename: "班级报表-#{Current.semester.name}-#{Current.campuse.name}.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
  end

  def index
    @sks = SemesterKlass.where(
      campuse_id: Current.campuse.id,
      semester_id: Current.semester.id,
      grade_id: allowed_grade_ids,
    ).includes(:grade, :subject, :teacher, :courses).to_a
      .sort_by { |sk| [ sk.grade.level, sk.subject.name, sk.genre, sk.seq ] }
    @active_counts = KlassStudent.where(semester_klass_id: @sks.map(&:id), status: "in").group(:semester_klass_id).count
    @reserve_rates = StatementReport.new(@sks, campuse: Current.campuse).rows
      .to_h { |row| [ row.semester_klass.id, row.reserve_rate ] }
    @total_courses = @sks.sum { |sk| sk.times.to_i }
    @started_courses = @sks.sum { |sk| sk.courses.count(&:started?) }
    @grade_groups = @sks.group_by(&:grade).sort_by { |grade, _| grade.level }
    @new_class_candidates = new_class_candidates
    set_teacher_groups
    set_grade_subject_times_defaults
  end

  def create
    unless allowed_grade_ids.include?(params.dig(:semester_klass, :grade_id).to_i)
      redirect_to admin_semester_klasses_path, alert: "无权操作该年级的班级"
      return
    end

    @sk = SemesterKlass.new(semester_klass_params.except(:students_text, :teacher_id))
    @sk.campuse_id = Current.campuse.id
    @sk.semester_id = Current.semester.id
    @sk.teacher = Current.campuse.teachers.find(params[:semester_klass][:teacher_id])
    @sk.subject = @sk.teacher.subject
    @sk.times = configured_times_for(@sk.grade_id, @sk.subject_id) if @sk.times.blank?
    @sk.seq = SemesterKlass.next_seq(
      campuse_id: @sk.campuse_id,
      semester_id: @sk.semester_id,
      grade_id: @sk.grade_id,
      subject_id: @sk.subject_id,
      genre: @sk.genre
    )

    if @sk.save
      apply_students(@sk)
      redirect_to admin_semester_klass_path(@sk), notice: "班级创建成功"
    else
      redirect_to admin_semester_klasses_path, alert: "班级创建失败，#{@sk.errors.full_messages.join("；")}"
    end
  end

  def update
    grade_id = params.dig(:semester_klass, :grade_id)
    if grade_id.present? && !allowed_grade_ids.include?(grade_id.to_i)
      redirect_to admin_semester_klasses_path, alert: "无权操作该年级的班级"
      return
    end

    @sk = campuse_semester_klasses.find(params[:id])
    teacher = Current.campuse.teachers.find(params[:semester_klass][:teacher_id])
    attrs = semester_klass_params.except(:students_text, :teacher_id).merge(teacher_id: teacher.id, subject_id: teacher.subject_id)
    attrs[:times] = @sk.times if attrs[:times].blank?

    if @sk.update(attrs)
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
    @sks = @q.result.joins(:semester, :grade, :subject).includes(:semester, :grade, :subject, :teacher, :students, :courses, klass_students: { student: :grade }).where(
      campuse_id: Current.campuse.id,
      grade_id: allowed_grade_ids,
    ).where(
      "semesters.seq < ?", @target_semester.seq
    ).order(
      "semesters.seq desc, grades.level asc, subjects.name asc, semester_klasses.genre asc, semester_klasses.seq asc"
    )
    @semesters = Semester.where(
      school_id: Current.school.id
    ).where(
      "semesters.seq < ?", @target_semester.seq,
    )
    @active_counts = KlassStudent.where(semester_klass_id: @sks.map(&:id), status: "in").group(:semester_klass_id).count
    set_teacher_groups
    @students_by_grade = Student.where(campuse_id: Current.campuse.id, grade_id: @sks.map(&:grade_id).uniq)
      .includes(:grade)
      .order(:name)
      .group_by(&:grade_id)
  end

  def copy_create
    unless allowed_grade_ids.include?(params.dig(:semester_klass, :grade_id).to_i)
      redirect_to copy_admin_semester_klasses_path, alert: "无权操作该年级的班级"
      return
    end

    target_semester = copy_target_semester
    @sk = SemesterKlass.new(semester_klass_params.except(:students_text, :teacher_id))
    @sk.semester_id = target_semester.id
    @sk.campuse_id = Current.campuse.id
    @sk.teacher = Current.campuse.teachers.find(params[:semester_klass][:teacher_id])
    @sk.subject = @sk.teacher.subject

    if @sk.save
      student_ids = Array(params[:student_ids]).reject(&:blank?)
      Student.where(id: student_ids, campuse_id: @sk.campuse_id, grade_id: @sk.grade_id).find_each do |student|
        student.join_klass(@sk, course_seq: 1)
      end

      if target_semester == Current.semester
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
    @sk = Current.semester.semester_klasses
      .where(campuse_id: Current.campuse.id, grade_id: allowed_grade_ids)
      .find(params[:id])
    send_data AttendanceSheet.new(@sk).to_xlsx,
      filename: "#{@sk.name}-#{@sk.semester.name}-考勤表.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
  end

  # 开班后的统一添加学员入口：选择入班课次后批量加入
  def insert_students
    @sk = campuse_semester_klasses.find(params[:id])
    student_ids = Array(params[:student_ids]).reject(&:blank?)

    if student_ids.empty?
      redirect_to admin_semester_klass_path(@sk), alert: "请先选择要添加的学员"
      return
    end

    join_seq = params[:join_course_seq].to_i.clamp(1, [ @sk.times.to_i, 1 ].max)
    students = Student.where(id: student_ids, campuse_id: @sk.campuse_id, grade_id: @sk.grade_id)
      .where.not(id: @sk.klass_students.select(:student_id)).to_a

    if students.empty?
      redirect_to admin_semester_klass_path(@sk), alert: "所选学员已在班级中，无需重复添加"
      return
    end

    students.each { |student| student.join_klass(@sk, course_seq: join_seq) }
    redirect_to admin_semester_klass_path(@sk), notice: "已添加 #{students.size} 名学员"
  end

  def show
    @sk = Current.semester.semester_klasses
      .where(campuse_id: Current.campuse.id, grade_id: allowed_grade_ids)
      .includes(:semester, :grade, :subject, :teacher)
      .find(params[:id])
    @sks = SemesterKlass.where(
      campuse_id: Current.campuse.id,
      semester_id: Current.semester.id,
      grade_id: allowed_grade_ids,
    ).includes(:grade, :subject, :teacher)
    @klass_students = @sk.klass_students.includes(:student).to_a
    @archived_klass_students = @sk.archived_klass_students.includes(:student).order(archived_at: :desc).to_a
    @courses = @sk.courses.order(:seq).to_a
    # 开课需按顺序：工具栏只提供下一个未开课课次
    @next_course = @courses.find { |course| !course.started? }
    @attendance_by_cell = Attendance.where(
      course_id: @courses.map(&:id),
      klass_student_id: @klass_students.map(&:id)
    ).includes(:marked_by).index_by { |attendance| [ attendance.course_id, attendance.klass_student_id ] }
    @active_student_count = @klass_students.count { |klass_student| klass_student.status == "in" }
    @left_klass_students = @klass_students.reject { |klass_student| klass_student.status == "in" }
    @leave_attendance_by_klass_student = Attendance
      .joins(:course)
      .where(klass_student_id: @left_klass_students.map(&:id), status: %w[quit transfer])
      .includes(:course)
      .order("courses.seq")
      .group_by(&:klass_student_id)
      .transform_values(&:first)
    @transfer_target_klasses = @sk.semester.semester_klasses
      .where(campuse_id: @sk.campuse_id, grade_id: @sk.grade_id)
      .where.not(id: @sk.id)
      .includes(:subject, :teacher)
      .order(:genre, :seq)
      .to_a
    transfer_target_ids = @transfer_target_klasses.map(&:id)
    @transfer_target_counts = KlassStudent.where(
      semester_klass_id: transfer_target_ids, status: "in"
    ).group(:semester_klass_id).count
    # 学员已加入的目标班：转出抽屉按学员动态隐藏，避免重复转入
    @enrolled_target_ids_by_student = KlassStudent
      .where(semester_klass_id: transfer_target_ids)
      .pluck(:student_id, :semester_klass_id)
      .group_by(&:first)
      .transform_values { |pairs| pairs.map(&:last) }
    set_teacher_groups
    set_grade_subject_times_defaults
    @insert_student_candidates = Student.where(
      campuse_id: Current.campuse.id,
      grade_id: @sk.grade_id
    ).where.not(id: @sk.klass_students.select(:student_id)).includes(:grade).order(:name)
    @new_class_candidates = new_class_candidates
  end

  private
  # 开班 / 复制时只列出当前校区的教师，科目按教师所属科目分组
  def set_teacher_groups
    @teacher_groups = Current.campuse.teachers.includes(:subject)
      .order(:subject_id, :name)
      .group_by(&:subject)
      .sort_by { |subject, _| subject.id }
      .map { |subject, teachers| [ subject.name, teachers.map { |teacher| [ teacher.name, teacher.id ] } ] }
  end

  def configured_times_for(grade_id, subject_id)
    Current.school.grade_subjects.find_by(
      semester_id: Current.semester.id, grade_id: grade_id, subject_id: subject_id
    )&.times || 16
  end

  def set_grade_subject_times_defaults
    grade_subjects = Current.school.grade_subjects.where(semester_id: Current.semester.id)
    @grade_subject_times = grade_subjects.pluck(:grade_id, :subject_id, :times)
      .to_h { |grade_id, subject_id, times| [ "#{grade_id}-#{subject_id}", times ] }
    @teacher_subjects = Current.campuse.teachers.pluck(:id, :subject_id)
      .to_h { |teacher_id, subject_id| [ teacher_id.to_s, subject_id ] }
  end

  def new_class_candidates
    Student.where(
      campuse_id: Current.campuse.id,
      grade_id: Current.user.grades_by_campuse(Current.campuse.id).ids
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
    return Current.semester if params[:target_semester_id].blank?

    Semester.where(school_id: Current.school.id)
      .where("seq >= ?", Current.semester.seq)
      .find_by(id: params[:target_semester_id]) || Current.semester
  end

  def copy_target_semesters
    Semester.where(school_id: Current.school.id)
      .where("seq >= ?", Current.semester.seq)
      .order(:seq, :id)
  end

  def statement_scope
    @q.result.joins(:semester, :grade, :subject)
      .includes(:semester, :grade, :subject, :teacher)
      .where(campuse_id: Current.campuse.id, grade_id: allowed_grade_ids)
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
    params.require(:semester_klass).permit(:genre, :seq, :times, :teacher_id, :grade_id, :students_text)
  end
end
