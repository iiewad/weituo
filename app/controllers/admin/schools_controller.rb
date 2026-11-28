class Admin::SchoolsController < AdminController
  before_action :require_admin

  def index
    # 引导模式（无校区）下没有当前学校上下文，列出全部学校供配置
    scope = Current.school ? School.where(id: Current.school.id) : School.all
    @schools = scope.includes(:campuses, :user_campuses)
  end

  def update
    @school = Current.school ? School.find(Current.school.id) : School.find(params[:id])
    known_campus_ids = @school.campuses.pluck(:id)

    if @school.update(school_params)
      granted = grant_access_to_new_campuses(known_campus_ids)
      notice = if granted.empty?
        "学校更新成功"
      else
        "学校更新成功，已为当前账号开通新校区：#{granted.join("、")}"
      end
      redirect_to admin_schools_path, notice: notice
    else
      redirect_to admin_schools_path, alert: "学校更新失败，#{@school.errors.full_messages.join("；")}"
    end
  end

  private
    # 校区授权在「用户管理」维护，但新建校区后当前超管会自动获得该校区权限，
    # 否则新校区不会出现在顶栏的校区切换菜单里，也无法进入配置。
    # 新校区还没有自己的年级字典，grade_ids 先为空，创建年级后在用户管理里勾选。
    def grant_access_to_new_campuses(known_campus_ids)
      @school.campuses.where.not(id: known_campus_ids).filter_map do |campuse|
        user_campuse = Current.user.user_campuses.find_or_initialize_by(campuse_id: campuse.id)
        next if user_campuse.persisted?

        user_campuse.role = "admin"
        user_campuse.grade_ids = campuse.grades.order(:level).ids
        user_campuse.save!
        campuse.name
      end
    end

    def school_params
      params
        .require(:school)
        .permit(:name,
          campuses_attributes: [ :id, :name, :_destroy ],
        )
    end
end
