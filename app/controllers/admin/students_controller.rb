class Admin::StudentsController < AdminController
  PER_PAGE_OPTIONS = [ 20, 30, 50, 100 ].freeze
  DEFAULT_PER_PAGE = 30

  def index
    @q = Student.ransack(params[:q])
    @grades = Current.user.grades_by_campuse(Current.campuse.id).order(:level)
    @day_schools = DaySchool.where(campuse_id: Current.campuse.id).order(:name)
    scoped = @q.result.where(
      campuse_id: Current.campuse.id,
      grade_id: @grades.ids
    )
    base = params[:filter].to_s == "deleted" ? scoped.deleted : scoped.active

    @per_page = PER_PAGE_OPTIONS.include?(params[:per_page].to_i) ? params[:per_page].to_i : DEFAULT_PER_PAGE
    @per_page_options = PER_PAGE_OPTIONS

    @students = base.includes(:grade, :day_school, :guardians, received_referral: :referrer)
    @students = apply_filter(@students, params[:filter]) if params[:filter].present?
    @students = @students.page(params[:page]).per(@per_page)

    @filter_counts = filter_counts(scoped)
    student_ids = @students.map(&:id)
    @history_by_student = klass_student_history(student_ids)
    @attendance_stats = attendance_stats_for(@history_by_student.values.flatten)
  end

  def create
    unless student_scope_valid?
      redirect_to admin_students_path, alert: "年级或日校不在当前校区授权范围内"
      return
    end

    @student = Student.new(student_params)
    @student.campuse_id = Current.campuse.id

    if @student.save
      redirect_to admin_students_path, notice: "学员创建成功"
    else
      redirect_to admin_students_path, alert: "学员创建失败，#{@student.errors.full_messages.join("；")}"
    end
  end

  # 开班时搜索不到学员的快速建档入口：只收姓名和年级，返回 JSON 供前端插入多选列表。
  def quick_create
    grade_id = params.dig(:student, :grade_id).to_i
    unless Current.user.grades_by_campuse(Current.campuse.id).exists?(id: grade_id)
      render json: { errors: [ "年级不在当前校区授权范围内" ] }, status: :unprocessable_entity
      return
    end

    student = Student.new(
      name: params.dig(:student, :name).to_s.strip,
      grade_id: grade_id,
      campuse_id: Current.campuse.id
    )

    if student.save
      render json: {
        id: student.id,
        name: student.name,
        identity_label: student.identity_label,
        identity_suffix: student.identity_suffix,
        grade_id: student.grade_id,
        grade_name: student.grade&.name
      }
    else
      render json: { errors: student.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # 推荐人选择器的远程候选：只按姓名搜索当前校区学员（允许跨年级），不返回无查询条件的全量列表。
  def options
    query = params[:q].to_s.strip
    return render json: [] if query.blank?

    scope = Student.active.where(campuse_id: Current.campuse.id).includes(:grade)
    scope = scope.where.not(id: params[:exclude_id]) if params[:exclude_id].present?
    scope = scope.where("students.name LIKE ?", "%#{Student.sanitize_sql_like(query)}%")

    render json: scope.order(:name).limit(20).map { |student| { id: student.id, name: student.name, detail: student.identity_detail } }
  end

  def template
    send_data StudentImportTemplate.new.to_xlsx,
      filename: "学员导入模板.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def import
    grade_ids = Current.user.grades_by_campuse(Current.campuse.id).ids

    if params[:students_file].present?
      unless File.extname(params[:students_file].original_filename.to_s).casecmp?(".xlsx")
        redirect_to admin_students_path, alert: "请上传 .xlsx 格式的 Excel 文件"
        return
      end

      begin
        created, skipped = Student.add_by_xlsx(Current.campuse.id, params[:students_file], grade_ids: grade_ids)
      rescue Roo::Error, Zip::Error, Errno::ENOENT
        redirect_to admin_students_path, alert: "Excel 文件读取失败，请确认文件内容与格式"
        return
      end
    else
      text = params[:students_text].to_s
      if text.strip.blank?
        redirect_to admin_students_path, alert: "请选择 Excel 文件或粘贴要导入的学员数据"
        return
      end

      created, skipped = Student.add_by_text(Current.campuse.id, text, grade_ids: grade_ids)
    end

    message = "新增 #{created} 名学员"
    message += "，跳过 #{skipped} 行（年级或日校不匹配、或已存在）" if skipped.positive?

    if created.positive?
      redirect_to admin_students_path, notice: message
    else
      redirect_to admin_students_path, alert: message
    end
  rescue ActiveRecord::ActiveRecordError
    redirect_to admin_students_path, alert: "导入失败，本批数据已全部回滚，请检查数据后重试"
  end

  def promote
    student_ids = Array(params[:student_ids]).reject(&:blank?)
    if student_ids.empty?
      redirect_back fallback_location: admin_students_path, alert: "请先勾选要升年级的学员"
      return
    end

    allowed_grade_ids = Current.user.grades_by_campuse(Current.campuse.id).ids
    students = Student.where(
      id: student_ids,
      campuse_id: Current.campuse.id,
      grade_id: allowed_grade_ids
    ).includes(:grade).to_a

    promoted = 0
    skipped = 0

    Student.transaction do
      students.group_by(&:grade).each do |grade, group|
        next_grade = Grade.find_by(level: grade.level + 1)
        unless next_grade && allowed_grade_ids.include?(next_grade.id)
          skipped += group.size
          next
        end

        Student.where(id: group.map(&:id)).update_all(grade_id: next_grade.id, updated_at: Time.current)
        promoted += group.size
      end
    end

    if promoted.zero?
      message = skipped.positive? ? "#{skipped} 名学员没有可升的年级" : "没有找到可升年级的学员"
      redirect_back fallback_location: admin_students_path, alert: message
      return
    end

    message = "已为 #{promoted} 名学员升年级"
    message += "，#{skipped} 名学员没有可升的年级已跳过" if skipped.positive?
    redirect_back fallback_location: admin_students_path, notice: message
  end

  def update
    unless student_scope_valid?
      redirect_to admin_students_path, alert: "年级或日校不在当前校区授权范围内"
      return
    end

    @student = Student.where(campuse_id: Current.campuse.id).find(params[:id])

    if @student.update(student_params)
      redirect_to admin_students_path, notice: "学员信息更新成功"
    else
      redirect_to admin_students_path, alert: "学员信息更新失败，#{@student.errors.full_messages.join("；")}"
    end
  end

  # 软删除：隐藏学员但保留班级与考勤历史，可在「已删除」中恢复
  def destroy
    @student = Current.campuse.students.find(params[:id])
    @student.soft_delete!
    redirect_to admin_students_path(student_list_params),
      notice: "#{@student.name} 已删除，可在「已删除」中恢复"
  end

  def restore
    @student = Current.campuse.students.find(params[:id])
    @student.restore!
    redirect_to admin_students_path(student_list_params.merge(filter: "deleted")),
      notice: "#{@student.name} 已恢复"
  end

  private
    # 删除 / 恢复后回到原来的筛选与搜索状态
    def student_list_params
      q = params[:q]
      q = q.to_unsafe_h if q.respond_to?(:to_unsafe_h)
      q = nil if q.blank?
      { filter: params[:filter].presence, per_page: params[:per_page].presence, q: q }.compact
    end

    def student_params
      params.require(:student).permit(
        :day_school_id, :name, :phone, :layer, :gender, :birthday, :in_date, :grade_id, :address, :remark, :referrer_id,
        guardians_attributes: [ :id, :name, :phone, :relationship, :occupation, :_destroy ]
      )
    end

    def student_scope_valid?
      grade_id = params.dig(:student, :grade_id)
      day_school_id = params.dig(:student, :day_school_id)
      grade_ok = grade_id.blank? || Current.user.grades_by_campuse(Current.campuse.id).exists?(id: grade_id)
      day_school_ok = day_school_id.blank? || Current.campuse.day_schools.exists?(id: day_school_id)

      grade_ok && day_school_ok
    end

    # 当前学期内的报名记录，用于「在班 / 有退课 / 未入班」筛选与计数
    def klass_students_in_current_semester
      KlassStudent.active.joins(:semester_klass).where(
        semester_klasses: { semester_id: Current.semester.id }
      )
    end

    def apply_filter(scope, filter)
      ks = klass_students_in_current_semester
      case filter
      when "in_class"
        scope.where(id: ks.where(status: "in").select(:student_id))
      when "out_class"
        scope.where(id: ks.where(status: "out").select(:student_id))
      when "not_in_class"
        scope.where.not(id: ks.where(status: %w[in out]).select(:student_id))
      else
        scope
      end
    end

    # 当前页学员的全部历史报名，按学期倒序，供详情抽屉追溯在班记录
    def klass_student_history(student_ids)
      # 上限取当前查看的学期（而非学校标记的 current），与页面范围、抽屉「当前学期」标记保持一致；
      # 否则切换到比 current 标记更新的学期时，该学期的班级会被过滤掉，抽屉看不到当前学期所在班级。
      current_seq = Current.semester&.seq
      KlassStudent
        .active
        .where(student_id: student_ids)
        .includes(semester_klass: [ :semester, :grade, :subject, :teacher ])
        .group_by(&:student_id)
        .transform_values do |records|
          records
            .select { |ks| current_seq.nil? || ks.semester_klass.semester.seq <= current_seq }
            .sort_by { |ks| [ -ks.semester_klass.semester.seq.to_i, ks.semester_klass.seq.to_i ] }
        end
    end

    def attendance_stats_for(klass_students)
      ids = klass_students.map(&:id)
      return {} if ids.empty?

      Attendance.where(klass_student_id: ids)
        .group(:klass_student_id, :status)
        .count
        .each_with_object({}) do |((klass_student_id, status), count), memo|
          (memo[klass_student_id] ||= {})[status] = count
        end
    end

    def filter_counts(scoped)
      active = scoped.active
      ks = klass_students_in_current_semester
      {
        all: active.count,
        in_class: active.where(id: ks.where(status: "in").select(:student_id)).count,
        out_class: active.where(id: ks.where(status: "out").select(:student_id)).count,
        not_in_class: active.where.not(id: ks.where(status: %w[in out]).select(:student_id)).count,
        deleted: scoped.deleted.count
      }
    end
end
