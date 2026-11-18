class Admin::SemestersController < AdminController
  def switch_thread_semester
    @semester = Thread.current[:school].semesters.find(params[:id])
    session[:current_semester_id] = @semester.id
    Thread.current[:semester] = @semester
    redirect_back fallback_location: root_path, notice: "学期切换成功"
  end
end
