class Admin::DashboardsController < AdminController
  def index
    @campuse = Current.campuse
    @semester = Current.semester
    @grades = Current.user.grades_by_campuse(@campuse.id).order(:level)
    grade_ids = @grades.ids

    @students_scope = Student.active.where(campuse_id: @campuse.id, grade_id: grade_ids)
    @student_count = @students_scope.count
    @new_students_this_semester = @semester ? @students_scope.where(in_semester_id: @semester.id).count : 0
    @teacher_count = Teacher.where(campuse_id: @campuse.id).count
    @recent_students = @students_scope.includes(:grade, :day_school, :in_semester).order(created_at: :desc).limit(5)

    if @semester
      @klasses_scope = SemesterKlass.where(campuse_id: @campuse.id, semester_id: @semester.id, grade_id: grade_ids)
      @klass_count = @klasses_scope.count
      @active_student_count = KlassStudent.active.joins(:semester_klass)
        .where(semester_klasses: { campuse_id: @campuse.id, semester_id: @semester.id, grade_id: grade_ids }, status: "in")
        .distinct.count(:student_id)
      @not_in_class_count = @students_scope.where.not(
        id: KlassStudent.active.joins(:semester_klass)
          .where(semester_klasses: { campuse_id: @campuse.id, semester_id: @semester.id }, status: %w[in out])
          .select(:student_id)
      ).count

      courses = Course.joins(:semester_klass)
        .where(semester_klasses: { campuse_id: @campuse.id, semester_id: @semester.id, grade_id: grade_ids })
      @total_courses = courses.count
      @started_courses = courses.where.not(start_date: nil).count
      @today_courses = courses.where(start_date: Date.current)
      @recent_klasses = @klasses_scope.includes(:grade, :subject, :teacher).order(created_at: :desc).limit(5).to_a
      @recent_active_counts = KlassStudent.active.where(semester_klass_id: @recent_klasses.map(&:id), status: "in")
        .group(:semester_klass_id).count
    else
      @klass_count = 0
      @active_student_count = 0
      @not_in_class_count = 0
      @total_courses = 0
      @started_courses = 0
      @today_courses = []
      @recent_klasses = []
      @recent_active_counts = {}
    end

    @progress = @total_courses.zero? ? 0 : (@started_courses * 100 / @total_courses)

    @guide_steps = guide_steps
    @show_guide = Current.user.guide_completed_at.nil? || params[:guide].present?
  end

  private
    # 新手引导步骤：按当前数据判断完成状态，超级管理员多一步课程配置
    def guide_steps
      admin = Current.user.has_role_by_campuse_id(Current.campuse.id, "admin")
      grade_subjects_ready = Current.semester.present? &&
        Current.campuse.grade_subjects.where(semester_id: Current.semester.id).exists?

      steps = [
        {
          title: "确认校区与学期",
          description: "用顶栏确认当前校区和学期。还没有新学期时，先到学期管理里创建学期并填写名称与序号。",
          done: Current.semester.present?,
          link: admin ? admin_semesters_path : nil,
          link_text: "学期管理"
        },
        {
          title: "配置年级科目与课次",
          description: "在年级科目管理中勾选本学期开设的年级 × 科目，并为每个组合设置默认课次；开班时会自动带出。",
          done: grade_subjects_ready,
          link: admin ? admin_grade_subjects_path : nil,
          link_text: "年级科目管理",
          admin_only: true
        },
        {
          title: "准备教师与学员",
          description: "在教师管理里维护授课教师（科目随教师），在学员管理里建档或批量导入；学员需要年级和日校（日校由超级管理员在「日校管理」维护）。",
          done: @teacher_count.positive? && @student_count.positive?,
          link: admin_teachers_path,
          link_text: "教师管理"
        },
        {
          title: "开班",
          description: "在班级管理里新建班级，或把上学期班级复制过来；课次会按年级科目配置自动生成。",
          done: @klass_count.positive?,
          link: admin_semester_klasses_path,
          link_text: "班级管理"
        },
        {
          title: "开课与考勤",
          description: "进入班级详情按顺序开课；点击考勤格记录缺课、请假、退课或转出，搜不到学员时可快速建档。",
          done: @started_courses.positive?,
          link: admin_semester_klasses_path,
          link_text: "去开课"
        },
        {
          title: "看报表、做续报",
          description: "在班级预留报表查看预留率；用「预留」或「复制」把当前学员带到下学期。",
          done: nil,
          link: statement_admin_semester_klasses_path,
          link_text: "班级预留报表"
        }
      ]

      steps.reject { |step| step[:admin_only] && !admin }
    end
end
