class Admin::CampusesController < AdminController
  def switch_thread_campuse
    @campuse = Campuse.find(params[:id])
    session[:current_campuse_id] = @campuse.id
    Thread.current[:current_campuse] = @campuse
    redirect_to request.referrer, notice: "校区切换成功"
  end
  def update
    @school = School.find(params[:school_id])
    @campus = @school.campuses.find(params[:id])
    if @campus.update(campus_params)
      redirect_to admin_schools_path, notice: "校区更新成功"
    else
      render :index
    end
  end
  private
    def campus_params
      params.require(:campuse).permit(:name)
    end
end
