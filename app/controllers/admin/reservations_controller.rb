class Admin::ReservationsController < AdminController
  # 预留表：只列出目标学期为当前所选学期的预留，可按学员姓名 / 年级 / 科目 / 班型 / 教师 / 状态筛选
  def index
    @grades = Grade.order(:level)
    @subjects = Subject.order(:id)
    @teachers = Current.campuse.teachers.includes(:subject).order(:name)
    @status = params[:status].presence_in(%w[pending generated all]) || "all"

    @q = Reservation.ransack(params[:q])
    scope = visible_reservations.merge(@q.result).ordered_by_target
    # 只列出目标学期为当前所选学期的预留；看其它学期请先切换学期
    scope = scope.where(semester_id: Current.semester.id) if Current.semester
    scope = scope.pending if @status == "pending"
    scope = scope.generated if @status == "generated"

    @pending_count = scope.pending.count
    @reservations = scope
      .includes(:student, :grade, :subject, :teacher, :semester_klass, :source_semester, :source_semester_klass)
      .page(params[:page])
    # 预留未指定教师（或教师已存档）的分组，批量进班时在这里选
    @teachers_by_subject = @teachers.reject(&:archived?).group_by(&:subject_id)

    # 批量进班：当前页待分班预留的分组（含可调整的班级信息）与可加入的已有班级
    page_pending = @reservations.reject(&:generated?)
    group_grades = page_pending.map(&:grade)
    @grade_options = (Current.user.grades_by_campuse(Current.campuse.id).order(:level).to_a | group_grades).sort_by(&:level)
    @batch_groups = page_pending.group_by(&:group_key).map do |_key, group|
      sample = group.first
      teacher = sample.teacher
      teacher = nil if teacher&.archived?
      {
        key: sample.group_key_string,
        label: batch_group_label(sample),
        semester_name: sample.semester.name,
        subject_name: sample.subject.name,
        grade_id: sample.grade_id,
        genre: sample.genre,
        phase: sample.phase,
        teacher_id: teacher&.id,
        teachers: @teachers_by_subject.fetch(sample.subject_id, []),
        times: configured_times(sample.semester, sample.grade, sample.subject)
      }
    end
    @batch_klasses = SemesterKlass
      .where(campuse_id: Current.campuse.id,
             semester_id: page_pending.map(&:semester_id).uniq,
             subject_id: page_pending.map(&:subject_id).uniq)
      .includes(:semester, :subject, :grade, :teacher)
      .to_a
      .sort_by(&:display_order_key)
  end

  # 批量进班：把选中的待分班预留学员按分组生成新班级（generate），或加入已有班级（join）
  def batch_enroll
    back = admin_reservations_path(**index_params)
    ids = Array(params[:reservation_ids]).map(&:to_i).uniq.reject(&:zero?)
    reservations = visible_reservations.pending
      .where(id: ids)
      .includes(:student, :source_semester_klass, :semester, :grade, :subject, :teacher)
      .to_a

    if reservations.empty?
      redirect_to back, alert: "请先选择待分班的预留学员"
      return
    end

    if params[:mode] == "join"
      batch_join_existing(reservations, back)
    else
      batch_generate_klasses(reservations, back)
    end
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

    # 按分组批量生成下学期班级，仅加入选中的预留学员；每个分组的班级信息（年级 / 班型 / 阶段 / 教师 / 课次）可单独调整
    def batch_generate_klasses(reservations, back)
      plans = reservations.group_by(&:group_key).map do |_key, group|
        sample = group.first
        [ sample, klass_settings_for(sample), group ]
      end

      if plans.any? { |_sample, settings, _group| settings[:teacher].blank? }
        redirect_to back, alert: "部分分组未选择本科目的在任教师，无法生成班级"
        return
      end

      klasses = []
      enrolled_total = 0
      grade_skipped_total = 0
      subject_skipped_total = 0
      ActiveRecord::Base.transaction do
        plans.each do |sample, settings, group|
          # 该分组无人升级到目标年级时整组跳过，不生成空班
          if group.none? { |reservation| reservation.student.grade_id == settings[:grade].id }
            grade_skipped_total += group.size
            next
          end

          klass = create_klass_for(
            semester: sample.semester, grade: settings[:grade], subject: sample.subject,
            genre: settings[:genre], phase: settings[:phase], teacher: settings[:teacher],
            times: settings[:times]
          )
          enrolled, grade_skipped, subject_skipped = enroll(klass, group)
          enrolled_total += enrolled
          grade_skipped_total += grade_skipped
          subject_skipped_total += subject_skipped
          klasses << klass
        end
      end

      if klasses.empty?
        redirect_to back, alert: "所选学员尚未升级到目标年级，请先在「学员管理」批量升级后再生成班级"
        return
      end

      notice = "已生成 #{klasses.size} 个班级，加入 #{enrolled_total} 名预留学员"
      notice += "（另有 #{grade_skipped_total} 名未升级，已跳过，升级后可再次生成）" if grade_skipped_total.positive?
      notice += "（另有 #{subject_skipped_total} 名已在同学期同科目其他班，已跳过）" if subject_skipped_total.positive?
      redirect_to back, notice: notice
    rescue ActiveRecord::RecordInvalid => e
      redirect_to back, alert: "生成班级失败：#{e.record.errors.full_messages.join("；")}"
    end

    # 读取弹窗里该分组自定义的班级信息，缺省时回退到预留本身的取值
    def klass_settings_for(sample)
      settings = params.dig(:groups, sample.group_key_string) || {}
      grade = Grade.find_by(id: settings[:grade_id]) || sample.grade
      genre = settings[:genre].presence_in(SemesterKlass::GENRE_MAP.values) || sample.genre
      phase = settings[:phase].to_i
      phase = sample.phase unless SemesterKlass::PHASE_PREFIX.key?(phase)
      times = settings[:times].to_i
      times = configured_times(sample.semester, grade, sample.subject) if times <= 0
      teacher = Current.campuse.teachers.active.find_by(id: settings[:teacher_id], subject_id: sample.subject_id)
      teacher ||= sample.teacher unless sample.teacher&.archived?

      {
        grade: grade,
        genre: genre,
        phase: phase,
        times: times,
        teacher: teacher
      }
    end

    # 把选中的预留学员加入一个已有班级（须同一目标学期、科目与年级）
    def batch_join_existing(reservations, back)
      klass = Current.campuse.semester_klasses
        .includes(:semester, :subject)
        .find_by(id: params[:klass_id])

      unless klass && reservations.all? { |reservation| same_target?(reservation, klass) }
        redirect_to back, alert: "所选学员须属于同一目标学期、科目与年级，且与所选班级一致"
        return
      end

      enrolled = 0
      grade_skipped = 0
      subject_skipped = 0
      ActiveRecord::Base.transaction { enrolled, grade_skipped, subject_skipped = enroll(klass, reservations) }

      notice = "已将 #{enrolled} 名学员加入班级 #{klass.name}"
      notice += "（另有 #{grade_skipped} 名年级与班级不符，已跳过）" if grade_skipped.positive?
      notice += "（另有 #{subject_skipped} 名已在同学期同科目其他班，已跳过）" if subject_skipped.positive?
      redirect_to back, notice: notice
    rescue ActiveRecord::RecordInvalid => e
      redirect_to back, alert: "加入班级失败：#{e.record.errors.full_messages.join("；")}"
    end

    def same_target?(reservation, klass)
      reservation.semester_id == klass.semester_id &&
        reservation.subject_id == klass.subject_id &&
        reservation.grade_id == klass.grade_id
    end

    def create_klass_for(semester:, grade:, subject:, genre:, phase:, teacher:, times: nil)
      times ||= configured_times(semester, grade, subject)
      SemesterKlass.create!(
        semester: semester, campuse: Current.campuse, grade: grade, subject: subject,
        teacher: teacher, genre: genre, phase: phase,
        seq: SemesterKlass.next_seq(
          campuse_id: Current.campuse.id, semester_id: semester.id,
          grade_id: grade.id, subject_id: subject.id, genre: genre, phase: phase
        ),
        times: times
      )
    end

    # 学员年级与班级年级一致才可进班：只加入已升级到目标年级的预留学员，
    # 未升级的跳过（预留保持待分班，升级后可再次生成 / 进班）；同学期已在同科目其他班的也跳过。
    # 返回 [已加入, 年级不符跳过, 同科目冲突跳过]
    def enroll(klass, reservations)
      enrolled = 0
      grade_skipped = 0
      subject_skipped = 0
      reservations.each do |reservation|
        if reservation.student.grade_id != klass.grade_id
          grade_skipped += 1
          next
        end

        # 年级已匹配，join_klass 仅在同学期同科目冲突（或班级无对应课次）时返回 nil，此时不标记预留已生成
        unless reservation.student.join_klass(klass, course_seq: 1)
          subject_skipped += 1
          next
        end

        reservation.update!(semester_klass_id: klass.id, teacher: klass.teacher)
        enrolled += 1
      end
      [ enrolled, grade_skipped, subject_skipped ]
    end

    def batch_group_label(reservation)
      "#{reservation.grade.name} · #{reservation.subject.name} · " \
        "#{SemesterKlass::GENRE_MAP_REVERSE[reservation.genre]} #{SemesterKlass::PHASE_PREFIX[reservation.phase]}"
    end

    def configured_times(semester, grade, subject)
      Current.school.grade_subjects.find_by(
        semester_id: semester.id, grade_id: grade.id, subject_id: subject.id
      )&.times || 16
    end
end
