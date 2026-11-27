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
    @reserve_min_attendances = Current.campuse.reserve_min_attendances
    report = StatementReport.new(statement_scope, campuse: Current.campuse,
      reserve_min_attendances: @reserve_min_attendances)
    @rows = report.rows
    @summary = report.summary
    @semesters = Semester.where(school_id: Current.school.id)
  end

  # 班级报表：调整本校区「预留」的最少上课次数
  def update_reserve_setting
    value = Integer(params[:reserve_min_attendances].to_s, exception: false)
    if value.nil? || value.negative?
      redirect_to statement_admin_semester_klasses_path, alert: "请输入不小于 0 的整数"
      return
    end

    if Current.campuse.update(reserve_min_attendances: value)
      redirect_to statement_admin_semester_klasses_path,
        notice: "预留设置已更新：下学期同科目班至少上 #{value} 次"
    else
      redirect_to statement_admin_semester_klasses_path, alert: "预留设置更新失败"
    end
  end

  def export_statement
    @q = SemesterKlass.ransack(params[:q])
    report = StatementReport.new(statement_scope, campuse: Current.campuse,
      reserve_min_attendances: Current.campuse.reserve_min_attendances)

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
    @q = SemesterKlass.ransack(params[:q])
    @sks = @q.result.where(
      campuse_id: Current.campuse.id,
      semester_id: Current.semester.id,
      grade_id: allowed_grade_ids,
    ).includes(:grade, :subject, :teacher, :courses).to_a
      .sort_by { |sk| [ sk.grade.level, sk.subject.name, *sk.display_order_key ] }
    @active_counts = KlassStudent.active.where(semester_klass_id: @sks.map(&:id), status: "in").group(:semester_klass_id).count
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

    @sk = SemesterKlass.new(semester_klass_params.except(:teacher_id))
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
      genre: @sk.genre,
      phase: @sk.phase
    )

    if @sk.save
      added, created, skipped = apply_students(@sk)
      redirect_to admin_semester_klass_path(@sk), notice: klass_saved_notice("班级创建成功", added, created, skipped)
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
    attrs = semester_klass_params.except(:teacher_id).merge(teacher_id: teacher.id, subject_id: teacher.subject_id)
    attrs[:times] = @sk.times if attrs[:times].blank?

    if @sk.update(attrs)
      added, created, skipped = apply_students(@sk)
      redirect_to admin_semester_klass_path(@sk), notice: klass_saved_notice("班级更新成功", added, created, skipped)
    else
      redirect_to admin_semester_klasses_path, alert: "班级更新失败，#{@sk.errors.full_messages.join("；")}"
    end
  end

  # 删除班级：已开课的班级保留考勤历史，不允许删除
  def destroy
    @sk = campuse_semester_klasses.find(params[:id])

    if @sk.courses.where.not(start_date: nil).exists?
      redirect_to admin_semester_klass_path(@sk), alert: "班级已有开课记录，不能删除"
      return
    end

    name = @sk.name
    @sk.destroy
    redirect_to admin_semester_klasses_path, notice: "已删除班级 #{name}"
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
    @active_counts = KlassStudent.active.where(semester_klass_id: @sks.map(&:id), status: "in").group(:semester_klass_id).count
    set_teacher_groups
    @students_by_grade = Student.active.where(campuse_id: Current.campuse.id, grade_id: @sks.map(&:grade_id).uniq)
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
    @sk = SemesterKlass.new(semester_klass_params.except(:teacher_id))
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
        source = campuse_semester_klasses.find_by(id: params[:return_klass_id]) if params[:return_klass_id].present?
        destination = source ? admin_semester_klass_path(source) : copy_admin_semester_klasses_path(target_semester_id: target_semester.id)
        redirect_to destination, notice: "复制成功，已在 #{target_semester.name} 生成 #{@sk.name}"
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

  # 预留下学期：把在班学员登记到预留表（目标年级 / 班型 / 教师可不同），分班在预留表中完成
  def reserve
    @sk = campuse_semester_klasses.find(params[:id])
    next_semester = @sk.semester.related_next_semester

    if next_semester.blank?
      redirect_to admin_semester_klass_path(@sk), alert: "下学期尚未创建，无法预留"
      return
    end

    student_ids = Array(params[:student_ids]).reject(&:blank?)
    students = @sk.klass_students.where(status: "in", student_id: student_ids).includes(:student).map(&:student)

    if students.empty?
      redirect_to admin_semester_klass_path(@sk), alert: "请选择要预留的学员"
      return
    end

    grade = Grade.find_by(id: params[:new_grade_id])
    # 教师可不指定，留到预留表生成分班时再选
    teacher = @sk.campuse.teachers.active.find_by(id: params[:new_teacher_id], subject_id: @sk.subject_id) if params[:new_teacher_id].present?
    genre = params[:new_genre].presence
    if grade.blank? || !reserve_grade_ids.include?(grade.id) || !SemesterKlass::GENRE_MAP.value?(genre)
      redirect_to admin_semester_klass_path(@sk), alert: "请选择目标年级和班型"
      return
    end
    if params[:new_teacher_id].present? && teacher.blank?
      redirect_to admin_semester_klass_path(@sk), alert: "所选教师不是本科目的在任教师"
      return
    end

    reserved = 0
    skipped = 0
    ActiveRecord::Base.transaction do
      students.each do |student|
        reservation = Reservation.find_or_initialize_by(
          student_id: student.id, semester_id: next_semester.id, subject_id: @sk.subject_id
        )
        # 已经生成下学期班级的记录不再改动
        if reservation.semester_klass_id.present?
          skipped += 1
          next
        end

        reservation.assign_attributes(grade: grade, genre: genre, teacher: teacher, source_semester_klass: @sk)
        if reservation.save
          reserved += 1
        else
          skipped += 1
        end
      end
    end

    if reserved.zero?
      redirect_to admin_semester_klass_path(@sk), alert: "没有学员被预留，可能已全部登记"
      return
    end

    notice = "已预留 #{reserved} 名学员到 #{next_semester.name}，可在「预留表」中分班"
    notice += "（跳过 #{skipped} 人）" if skipped.positive?
    redirect_to admin_semester_klass_path(@sk), notice: notice
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
    @next_semester = @sk.semester.related_next_semester
    @reserved_student_ids = @sk.reserve_students.map(&:id)
    @reserve_candidates = @sk.klass_students.where(status: "in").includes(:student)
      .reject { |klass_student| @reserved_student_ids.include?(klass_student.student_id) }
    @reserve_grade_ids = reserve_grade_ids
    @reserve_grades = Grade.where(id: @reserve_grade_ids).order(:level).to_a
    @reserve_default_grade = @reserve_grades.find { |grade| grade.level == @sk.grade.level + 1 } || @sk.grade
    @reserve_teachers = @sk.campuse.teachers.active.where(subject_id: @sk.subject_id).order(:name).to_a
    @target_semester = @next_semester
    @active_counts = { @sk.id => @active_student_count }
    @students_by_grade = if @next_semester
      Student.where(campuse_id: @sk.campuse_id, grade_id: @sk.grade_id)
        .includes(:grade).order(:name).group_by(&:grade_id)
    else
      {}
    end
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
      .to_a
      .sort_by(&:display_order_key)
    transfer_target_ids = @transfer_target_klasses.map(&:id)
    @transfer_target_counts = KlassStudent.active.where(
      semester_klass_id: transfer_target_ids, status: "in"
    ).group(:semester_klass_id).count
    # 学员已加入的目标班：转出抽屉按学员动态隐藏，避免重复转入
    @enrolled_target_ids_by_student = KlassStudent
      .active
      .where(semester_klass_id: transfer_target_ids)
      .pluck(:student_id, :semester_klass_id)
      .group_by(&:first)
      .transform_values { |pairs| pairs.map(&:last) }
    set_teacher_groups
    set_grade_subject_times_defaults
    @new_class_candidates = new_class_candidates
  end

  private
  # 开班 / 复制时只列出当前校区的教师，科目按教师所属科目分组
  def set_teacher_groups
    teachers = Current.campuse.teachers.active.includes(:subject).order(:subject_id, :name).to_a
    # 已存档教师仍要能显示在所属班级的编辑表单里，避免保存时被替换
    if @sk&.teacher_id.present? && teachers.none? { |teacher| teacher.id == @sk.teacher_id }
      teachers << @sk.teacher
    end
    @teacher_groups = teachers.group_by(&:subject)
      .sort_by { |subject, _| subject.id }
      .map { |subject, list| [ subject.name, list.map { |teacher| [ teacher.name, teacher.id ] } ] }
  end

  def reserve_grade_ids
    ids = [ @sk.grade_id ]
    next_grade = Grade.find_by(level: @sk.grade.level + 1)
    ids << next_grade.id if next_grade
    ids
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
    @teacher_subjects = Current.campuse.teachers.active.pluck(:id, :subject_id)
      .to_h { |teacher_id, subject_id| [ teacher_id.to_s, subject_id ] }
    @teacher_subjects[@sk.teacher_id.to_s] = @sk.subject_id if @sk&.teacher_id
  end

  def new_class_candidates
    Student.active.where(
      campuse_id: Current.campuse.id,
      grade_id: Current.user.grades_by_campuse(Current.campuse.id).ids
    ).includes(:grade).order(:name)
  end

  # 开班 / 编辑班级时的学员来源：粘贴名单优先，否则按勾选的学员 id 加入
  def apply_students(semester_klass)
    if params[:students_text].present?
      return join_students_from_text(semester_klass, params[:students_text], default_seq: params[:join_course_seq])
    end

    student_ids = Array(params[:student_ids]).reject(&:blank?)
    return [ 0, 0, 0 ] if student_ids.empty?

    max_seq = [ semester_klass.times.to_i, 1 ].max
    join_seq = [ [ params[:join_course_seq].to_i, 1 ].max, max_seq ].min
    joined = Student.where(id: student_ids, campuse_id: semester_klass.campuse_id, grade_id: semester_klass.grade_id)
      .where.not(id: semester_klass.klass_students.select(:student_id)).to_a
    joined.each { |student| student.join_klass(semester_klass, course_seq: join_seq) }

    [ joined.size, 0, 0 ]
  end

  # 粘贴名单：每行「姓名」或「姓名,入班课次」；课次留空用表单里的入班课次。
  # 姓名在本班年级没有档案时直接建档后再入班；已在班的同名学员跳过。
  def join_students_from_text(semester_klass, text, default_seq:)
    max_seq = [ semester_klass.times.to_i, 1 ].max
    fallback = default_seq.to_i.clamp(1, max_seq)
    candidates = Student.active.where(campuse_id: semester_klass.campuse_id, grade_id: semester_klass.grade_id)
    added = 0
    created = 0
    skipped = 0

    text.to_s.split("\n").each do |line|
      name, seq = parse_student_line(line)
      next if name.blank?

      student = candidates.where(name: name)
        .where.not(id: semester_klass.klass_students.select(:student_id))
        .order(:id).first

      if student.blank?
        # 同名学员都在班或档案已被删除时跳过，其余按本班年级新建
        if candidates.where(name: name).exists? ||
           Student.deleted.where(campuse_id: semester_klass.campuse_id, grade_id: semester_klass.grade_id, name: name).exists?
          skipped += 1
          next
        end

        student = Student.new(name: name, grade_id: semester_klass.grade_id, campuse_id: semester_klass.campuse_id)
        begin
          unless student.save
            skipped += 1
            next
          end
        rescue ActiveRecord::ActiveRecordError
          skipped += 1
          next
        end
        created += 1
      end

      student.join_klass(semester_klass, course_seq: [ seq || fallback, max_seq ].min)
      added += 1
    end

    [ added, created, skipped ]
  end

  # 兼容「姓名,课次」「姓名 课次」两种写法
  def parse_student_line(line)
    parts = line.to_s.strip.split(/[,，\t]/).map(&:strip)
    parts = parts.first.to_s.split(/\s+/) if parts.size < 2
    seq = parts[1].to_i
    [ parts[0].to_s, (seq.positive? ? seq : nil) ]
  end

  def klass_saved_notice(base, added, created, skipped)
    parts = []
    parts << "已加入 #{added} 名学员" if added.positive?
    parts << "其中新建 #{created} 名学员" if created.positive?
    parts << "跳过 #{skipped} 行（已在班或姓名无效）" if skipped.positive?
    parts.empty? ? base : "#{base}，#{parts.join("，")}"
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

    parts << "全部班级" if parts.empty?
    parts << "预留：下学期同科目班至少上 #{Current.campuse.reserve_min_attendances} 次"
    parts.join(" · ")
  end

  def semester_klass_params
    params.require(:semester_klass).permit(:genre, :seq, :times, :teacher_id, :grade_id, :phase)
  end
end
