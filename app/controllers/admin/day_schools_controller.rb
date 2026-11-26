class Admin::DaySchoolsController < AdminController
  before_action :require_admin

  def index
    @day_schools = Current.campuse.day_schools.order(:name)
    @student_counts = Student.active.where(campuse_id: Current.campuse.id)
      .where.not(day_school_id: nil)
      .group(:day_school_id).count
  end

  def create
    day_school = Current.campuse.day_schools.new(day_school_params)

    if day_school.save
      respond_to do |format|
        format.html { redirect_to admin_day_schools_path, notice: "日校已添加" }
        format.json { render json: { id: day_school.id, name: day_school.name }, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to admin_day_schools_path, alert: "日校添加失败，#{day_school.errors.full_messages.join("；")}" }
        format.json { render json: { errors: day_school.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # 粘贴名单导入日校：每行一个名称
  def import
    text = params[:day_schools_text].to_s
    if text.strip.blank?
      redirect_to admin_day_schools_path, alert: "请粘贴日校名单"
      return
    end

    created, skipped = DaySchool.add_by_text(Current.campuse.id, text)
    if created.zero?
      redirect_to admin_day_schools_path, alert: "没有新增日校，请检查名称是否为空或已存在"
    else
      parts = [ "新增 #{created} 个日校" ]
      parts << "跳过 #{skipped} 行（名称为空或已存在）" if skipped.positive?
      redirect_to admin_day_schools_path, notice: parts.join("，")
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
    student_count = Student.active.where(day_school_id: day_school.id).count

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
