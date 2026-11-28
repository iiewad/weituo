class Admin::UsersController < AdminController
  before_action :require_admin

  def index
    @users = users_in_current_school.includes(user_campuses: :campuse).order(:name)
    @campuses = Current.school.campuses.order(:name, :id)
    @grades = Grade.where(campuse_id: @campuses.select(:id)).order(:level).to_a
    @grades_by_id = @grades.index_by(&:id)
  end

  def create
    sanitize_grade_ids!
    unless user_campuses_within_school?
      redirect_to admin_users_path, alert: "无权授予其他学校的校区权限"
      return
    end

    @user = User.new(user_params)
    if @user.save
      redirect_to admin_users_path, notice: "用户创建成功"
    else
      redirect_to admin_users_path, alert: "用户创建失败，#{@user.errors.full_messages.join("；")}"
    end
  end

  def update
    sanitize_grade_ids!
    unless user_campuses_within_school?
      redirect_to admin_users_path, alert: "无权授予其他学校的校区权限"
      return
    end

    @user = users_in_current_school.find(params[:id])
    if @user.update(user_params)
      redirect_to admin_users_path, notice: "用户更新成功"
    else
      redirect_to admin_users_path, alert: "用户更新失败，#{@user.errors.full_messages.join("；")}"
    end
  end

  private
    # 年级按校区隔离：前端 chip 过滤可被绕过，服务端再按行所属校区剔除越界的年级 id
    def sanitize_grade_ids!
      rows = params.dig(:user, :user_campuses_attributes)
      return unless rows

      rows.each_value do |row|
        next if row[:grade_ids].blank?

        campuse_id = row[:campuse_id].presence || UserCampuse.find_by(id: row[:id])&.campuse_id
        next if campuse_id.blank?

        allowed = Grade.where(campuse_id:).pluck(:id)
        row[:grade_ids] = Array(row[:grade_ids]).map(&:to_i).select { |id| allowed.include?(id) }
      end
    end

    def users_in_current_school
      User.where(id: UserCampuse.where(school_id: Current.school.id).select(:user_id))
    end

    def user_campuses_within_school?
      rows = params.dig(:user, :user_campuses_attributes) || {}
      rows.each_value.all? do |row|
        if row[:id].present?
          user_campuse = UserCampuse.find_by(id: row[:id])
          next false unless user_campuse && user_campuse.school_id == Current.school.id
        end

        campuse_id = row[:campuse_id]
        campuse_id.blank? || Current.school.campuses.exists?(id: campuse_id)
      end
    end

    def user_params
      params.require(:user).permit(
        :name, :password,
        user_campuses_attributes: [ :id, :campuse_id, :role, :_destroy, grade_ids: [] ]
      )
    end
end
