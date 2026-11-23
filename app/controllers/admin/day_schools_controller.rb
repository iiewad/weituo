class Admin::DaySchoolsController < AdminController
  before_action :require_admin

  def index
    @day_schools = Current.campuse.day_schools.order(:name)
    @student_counts = Student.where(campuse_id: Current.campuse.id)
      .where.not(day_school_id: nil)
      .group(:day_school_id).count
  end

  def create
    day_school = Current.campuse.day_schools.new(day_school_params)

    if day_school.save
      redirect_to admin_day_schools_path, notice: "日校已添加"
    else
      redirect_to admin_day_schools_path, alert: "日校添加失败，#{day_school.errors.full_messages.join("；")}"
    end
  end

  def update
    day_school = Current.campuse.day_schools.find(params[:id])

    if day_school.update(day_school_params)
      redirect_to admin_day_schools_path, notice: "日校已更新"
    else
      redirect_to admin_day_schools_path, alert: "日校更新失败，#{day_school.errors.full_messages.join("；")}"
    end
  end

  def destroy
    day_school = Current.campuse.day_schools.find(params[:id])
    student_count = Student.where(day_school_id: day_school.id).count

    if student_count.positive?
      redirect_to admin_day_schools_path, alert: "该日校下还有 #{student_count} 名学员，不能删除"
      return
    end

    day_school.destroy
    redirect_to admin_day_schools_path, notice: "日校已删除"
  end

  private
    def day_school_params
      params.require(:day_school).permit(:name)
    end
end
