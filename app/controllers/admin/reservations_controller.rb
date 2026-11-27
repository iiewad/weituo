class Admin::ReservationsController < AdminController
  # 预留表：列出所有预留学员，可按学员姓名 / 源学期 / 预留目标学期 / 年级 / 科目 / 班型 / 教师 / 状态筛选
  def index
    @semesters = Current.school.semesters.order(:seq)
    @grades = Grade.order(:level)
    @subjects = Subject.order(:id)
    @teachers = Current.campuse.teachers.includes(:subject).order(:name)
    @status = params[:status].presence_in(%w[pending generated all]) || "all"

    @q = Reservation.ransack(params[:q])
    scope = visible_reservations.merge(@q.result).ordered_by_target
    scope = scope.pending if @status == "pending"
    scope = scope.generated if @status == "generated"

    @pending_count = scope.pending.count
    @reservations = scope
      .includes(:student, :grade, :subject, :teacher, :semester_klass, :source_semester, :source_semester_klass)
      .page(params[:page])
    # 「生成班级」作用于整个分组，按钮上要提示该组人数
    @group_sizes = visible_reservations.pending.includes(:source_semester_klass)
      .group_by(&:group_key).transform_values(&:size)
    # 预留未指定教师（或教师已存档）的分组，生成班级时在这里选
    @teachers_by_subject = @teachers.reject(&:archived?).group_by(&:subject_id)
  end

  # 按分组生成下学期班级，并把该组待分班的预留学员加入班级。
  # 预留未指定教师的分组，由 teacher_id 指定新班级的教师；group_teacher_id 是分组本身的教师
  def generate
    semester = Current.school.semesters.find_by(id: params[:semester_id])
    grade = Grade.find_by(id: params[:grade_id])
    subject = Subject.find_by(id: params[:subject_id])
    group_teacher_id = params[:group_teacher_id].presence
    teacher = Current.campuse.teachers.active.find_by(id: params[:teacher_id], subject_id: subject&.id)
    genre = params[:genre]
    phase = params[:phase].to_i

    back = admin_reservations_path(**index_params)
    unless semester && grade && subject &&
           SemesterKlass::GENRE_MAP.value?(genre) && SemesterKlass::PHASE_PREFIX.key?(phase)
      redirect_to back, alert: "预留信息不完整，无法生成班级"
      return
    end

    unless teacher
      redirect_to back, alert: "请选择本科目的在任教师后再生成班级"
      return
    end

    reservations = visible_reservations.pending
      .where(semester_id: semester.id, grade_id: grade.id, subject_id: subject.id, genre: genre, teacher_id: group_teacher_id)
      .to_a
      .select { |reservation| reservation.phase == phase }

    if reservations.empty?
      redirect_to back, alert: "该分组没有待分班的预留学员"
      return
    end

    klass = nil
    ActiveRecord::Base.transaction do
      klass = SemesterKlass.create!(
        semester: semester, campuse: Current.campuse, grade: grade, subject: subject,
        teacher: teacher, genre: genre, phase: phase,
        seq: SemesterKlass.next_seq(
          campuse_id: Current.campuse.id, semester_id: semester.id,
          grade_id: grade.id, subject_id: subject.id, genre: genre, phase: phase
        ),
        times: configured_times(semester, grade, subject)
      )
      reservations.each do |reservation|
        reservation.student.join_klass(klass, course_seq: 1, allow_grade_mismatch: true)
        reservation.update!(semester_klass_id: klass.id, teacher: klass.teacher)
      end
    end

    redirect_to back, notice: "已生成班级 #{klass.name}，加入 #{reservations.size} 名预留学员"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to back, alert: "生成班级失败：#{e.record.errors.full_messages.join("；")}"
  end

  # 修改预留目标（年级 / 班型 / 教师）；已生成班级的预留不可改
  def update
    reservation = visible_reservations.find(params[:id])
    if reservation.generated?
      redirect_back_or_to admin_reservations_path, alert: "已生成班级的预留不能修改，请在对应班级中调整"
      return
    end

    grade = Grade.find_by(id: params[:grade_id])
    genre = params[:genre]
    teacher = reservation.student.campuse.teachers.active.find_by(id: params[:teacher_id], subject_id: reservation.subject_id) if params[:teacher_id].present?

    if grade.blank? || !reservation.editable_grades.exists?(grade.id) || !SemesterKlass::GENRE_MAP.value?(genre)
      redirect_back_or_to admin_reservations_path, alert: "请选择目标年级和班型"
      return
    end
    if params[:teacher_id].present? && teacher.blank?
      redirect_back_or_to admin_reservations_path, alert: "所选教师不是本科目的在任教师"
      return
    end

    reservation.update!(grade: grade, genre: genre, teacher: teacher)
    redirect_back_or_to admin_reservations_path, notice: "已更新 #{reservation.student.name} 的预留"
  rescue ActiveRecord::RecordInvalid => e
    redirect_back_or_to admin_reservations_path, alert: "更新预留失败：#{e.record.errors.full_messages.join("；")}"
  end

  # 取消预留；已生成班级的预留不可取消
  def destroy
    reservation = visible_reservations.find(params[:id])
    if reservation.generated?
      redirect_back_or_to admin_reservations_path, alert: "已生成班级的预留不能取消，请在对应班级中移出学员"
      return
    end

    reservation.destroy!
    redirect_back_or_to admin_reservations_path, notice: "已取消 #{reservation.student.name} 的预留"
  end

  private
    # 授权范围：预留的目标年级，或来源班级的年级（预留到高一年级时，仍能看到自己班的学员）
    def visible_reservations
      scope = Reservation.joins(:student).where(students: { campuse_id: Current.campuse.id, deleted_at: nil })

      scope.where(grade_id: allowed_grade_ids)
        .or(scope.where(source_semester_klass_id: SemesterKlass.where(grade_id: allowed_grade_ids).select(:id)))
    end

    def index_params
      { q: params[:q]&.to_unsafe_h, status: params[:status] }.compact
    end

    def configured_times(semester, grade, subject)
      Current.school.grade_subjects.find_by(
        semester_id: semester.id, grade_id: grade.id, subject_id: subject.id
      )&.times || 16
    end
end
