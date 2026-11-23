class Admin::CoursesController < AdminController
  def start
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    @course = @sk.courses.find(params[:id])

    if @course.start!
      redirect_to admin_semester_klass_path(@sk), notice: "第 #{@course.seq} 课考勤已开始"
    elsif @course.started?
      redirect_to admin_semester_klass_path(@sk), alert: "第 #{@course.seq} 课已开课，无需重复操作"
    else
      blocked = @sk.courses.where("seq < ?", @course.seq).where(start_date: nil).order(:seq).first
      redirect_to admin_semester_klass_path(@sk),
        alert: "请先开第 #{blocked.seq} 课，开课需按课次顺序进行"
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to admin_semester_klass_path(@sk), alert: "该课次正在开课，请刷新后重试"
  end
end
