class Admin::CoursesController < AdminController
  def start
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    @course = @sk.courses.find(params[:id])

    unless @course.previous_courses_started?
      blocked = @sk.courses.where("seq < ?", @course.seq).where(start_date: nil).order(:seq).first
      redirect_to admin_semester_klass_path(@sk),
        alert: "请先开第 #{blocked.seq} 课，开课需按课次顺序进行"
      return
    end

    @course.start!
    redirect_to admin_semester_klass_path(@sk), notice: "考勤已开始"
  end
end
