class Admin::StudentsController < AdminController
  def index
    @q = Student.ransack(params[:q])
    @grades = Current.user.grades_by_campuse(Thread.current[:campuse].id).order(:level)
    @day_schools = DaySchool.where(campuse_id: Thread.current[:campuse].id).order(:name)
    base = @q.result.where(
      campuse_id: Thread.current[:campuse].id,
      grade_id: @grades.ids
    )

    @students = base.includes(:grade, :day_school, :guardians)
    @students = apply_filter(@students, params[:filter]) if params[:filter].present?
    @students = @students.page(params[:page])

    @filter_counts = filter_counts(base)
    @klass_students_by_student = klass_students_by_student(@students.map(&:id))
  end

  def create
    @student = Student.new(student_params)
    @student.campuse_id = Thread.current[:campuse].id

    if @student.save
      redirect_to admin_students_path, notice: "学员创建成功"
    else
      redirect_to admin_students_path, alert: "学员创建失败，#{@student.errors.full_messages.join("；")}"
    end
  end

  def update
    @student = Student.where(campuse_id: Thread.current[:campuse].id).find(params[:id])

    if @student.update(student_params)
      redirect_to admin_students_path, notice: "学员信息更新成功"
    else
      redirect_to admin_students_path, alert: "学员信息更新失败，#{@student.errors.full_messages.join("；")}"
    end
  end

  private
    def student_params
      params.require(:student).permit(
        :day_school_id, :name, :phone, :layer, :gender, :birthday, :in_date, :grade_id,
        guardians_attributes: [ :id, :name, :phone, :relationship, :_destroy ]
      )
    end

    # 当前学期内的报名记录，用于「在班 / 有退课 / 未入班」筛选与计数
    def klass_students_in_current_semester
      KlassStudent.joins(:semester_klass).where(
        semester_klasses: { semester_id: Thread.current[:semester].id }
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

    # 当前学期内、当前页学员的报名记录，按学员分组供抽屉内的「班级信息」模块使用
    def klass_students_by_student(student_ids)
      KlassStudent
        .joins(:semester_klass)
        .where(semester_klasses: { semester_id: Thread.current[:semester].id }, student_id: student_ids)
        .includes(semester_klass: [ :subject, :teacher ])
        .group_by(&:student_id)
    end

    def filter_counts(base)
      ks = klass_students_in_current_semester
      {
        all: base.count,
        in_class: base.where(id: ks.where(status: "in").select(:student_id)).count,
        out_class: base.where(id: ks.where(status: "out").select(:student_id)).count,
        not_in_class: base.where.not(id: ks.where(status: %w[in out]).select(:student_id)).count
      }
    end
end
