class Admin::SemestersController < AdminController
  def switch_thread_semester
    @semester = Current.school.semesters.find(params[:id])
    session[:current_semester_id] = @semester.id
    Current.semester = @semester
    redirect_back fallback_location: root_path, notice: "学期切换成功"
  end
end
