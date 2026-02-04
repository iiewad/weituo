class Admin::SemestersController < AdminController
  def switch_thread_semester
    @semester = Semester.find(params[:id])
    session[:current_semester_id] = @semester.id
    Thread.current[:semester] = @semester
    redirect_to request.referrer, notice: "学期切换成功"
  end
end
