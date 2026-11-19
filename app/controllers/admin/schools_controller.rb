class Admin::SchoolsController < AdminController
  before_action :require_admin

  def index
    @schools = School.where(id: Current.school.id)
      .includes(:campuses, :semesters, :grade_subjects, :user_campuses)
  end

  def update
    @school = School.find(Current.school.id)

    if @school.update(school_params)
      redirect_to admin_schools_path, notice: "学校更新成功"
    else
      redirect_to admin_schools_path, alert: "学校更新失败，#{@school.errors.full_messages.join("；")}"
    end
  end

  private
    def school_params
      params
        .require(:school)
        .permit(:name,
          campuses_attributes: [ :id, :name, :_destroy ],
          semesters_attributes: [ :id, :name, :start_date, :end_date, :seq, :_destroy ],
        )
    end
end
