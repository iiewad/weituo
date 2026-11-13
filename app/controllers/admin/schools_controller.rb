class Admin::SchoolsController < AdminController
  def index
    @schools = School.includes(:campuses, :semesters, :grade_subjects, :user_campuses).all
  end

  def update
    @school = School.find(params[:id])

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
          grade_subjects_attributes: [ :id, :grade_id, :subject_id, :_destroy ],
          semesters_attributes: [ :id, :name, :start_date, :end_date, :seq, :_destroy ],
          user_campuses_attributes: [ :id, :user_id, :campuse_id, :role, :_destroy, grade_ids: [] ],
        )
    end
end
