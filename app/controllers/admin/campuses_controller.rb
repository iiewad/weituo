class Admin::CampusesController < AdminController
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
