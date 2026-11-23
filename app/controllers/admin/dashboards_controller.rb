class Admin::DashboardsController < AdminController
  def index
    @campuse = Current.campuse
    @semester = Current.semester
    @grades = Current.user.grades_by_campuse(@campuse.id).order(:level)
    grade_ids = @grades.ids

    @students_scope = Student.where(campuse_id: @campuse.id, grade_id: grade_ids)
    @student_count = @students_scope.count
    @new_students_this_month = @students_scope.where(in_date: Date.current.beginning_of_month..Date.current).count
    @teacher_count = Teacher.where(campuse_id: @campuse.id).count
    @recent_students = @students_scope.includes(:grade, :day_school).order(created_at: :desc).limit(5)

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
  end
end
