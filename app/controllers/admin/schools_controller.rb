class Admin::SchoolsController < AdminController
  def index
    @schools = School.includes(:campuses).all
  end

  def update
    @school = School.find(params[:id])
    if @school.update(school_params)
      redirect_to admin_schools_path, notice: "学校更新成功"
    else
      render :index
    end
  end

  private
    def school_params
      params.require(:school).permit(:name, campuses_attributes: [ :id, :name, :_destroy ])
    end
end
