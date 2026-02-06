class Admin::CoursesController < AdminController
  def start
    @sk = SemesterKlass.find(params[:semester_klass_id])
    @klass = @sk.klass
    @course = @sk.courses.find(params[:id])
    @course.start!
    redirect_to admin_semester_klass_path(@sk), notice: "考勤已开始"
  end
end
