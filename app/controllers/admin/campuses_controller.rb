class Admin::CampusesController < AdminController
  before_action :require_admin, only: :update

  def switch_thread_campuse
    @campuse = Current.user.campuses.find(params[:id])
    session[:current_campuse_id] = @campuse.id
    Current.campuse = @campuse
    Current.school = @campuse.school
    redirect_after_context_switch("校区切换成功")
  end

  def update
    @school = Current.school
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
