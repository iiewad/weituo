class Admin::CoursesController < AdminController
  def start
    @klass = Klass.find(params[:klass_id])
    @course = @klass.courses.find(params[:id])
    @course.start!
    redirect_to admin_klass_path(@klass), notice: "考勤已开始"
  end
end
