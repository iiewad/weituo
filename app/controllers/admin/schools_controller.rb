class Admin::SchoolsController < AdminController
  def index
    @schools = School.includes(:campuses).all
  end

  def update
    @school = School.find(params[:id])

    # 添加调试信息
    puts "\n=== 调试信息 ==="
    puts "请求参数: #{params[:school]}"
    puts "年级科目属性: #{params[:school][:grade_subjects_attributes]}"
    puts "=== 调试信息 ===\n"

    if @school.update(school_params)
      redirect_to admin_schools_path, notice: "学校更新成功"
    else
      render :index
    end
  end

  private
    def school_params
      params.require(:school).permit(:name, campuses_attributes: [ :id, :name, :_destroy ], grade_subjects_attributes: [ :id, :grade_id, :subject_id, :_destroy ], semesters_attributes: [ :id, :name, :start_date, :end_date, :_destroy ])
    end
end
