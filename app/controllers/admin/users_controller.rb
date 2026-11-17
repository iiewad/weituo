class Admin::UsersController < AdminController
  before_action :require_admin

  def index
    @users = User.includes(user_campuses: :campuse).order(:name)
    @campuses = Campuse.includes(:school).order(:school_id, :name, :id)
    @grades = Grade.order(:level).to_a
    @grades_by_id = @grades.index_by(&:id)
    @grade_school_ids = GradeSubject.pluck(:grade_id, :school_id)
      .group_by(&:first)
      .transform_values { |pairs| pairs.map(&:last).uniq }
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to admin_users_path, notice: "用户创建成功"
    else
      redirect_to admin_users_path, alert: "用户创建失败，#{@user.errors.full_messages.join("；")}"
    end
  end

  def update
    @user = User.find(params[:id])
    if @user.update(user_params)
      redirect_to admin_users_path, notice: "用户更新成功"
    else
      redirect_to admin_users_path, alert: "用户更新失败，#{@user.errors.full_messages.join("；")}"
    end
  end

  private
    def require_admin
      return if Current.user.has_role_by_campuse_id(Thread.current[:campuse]&.id, "admin")

      redirect_to root_path, alert: "只有超级管理员可以管理用户与校区授权"
    end

    def user_params
      params.require(:user).permit(
        :name, :password,
        user_campuses_attributes: [ :id, :campuse_id, :role, :_destroy, grade_ids: [] ]
      )
    end
end
