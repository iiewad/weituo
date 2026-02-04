class Admin::UsersController < AdminController
  def index
    @users = User.all
  end

  def edit
    @user = User.find(params[:id])
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to admin_users_path, notice: "用户创建成功"
    else
      render :new
    end
  end

  def update
    @user = User.find(params[:id])
    if @user.update(user_params)
      redirect_to admin_users_path, notice: "用户更新成功"
    else
      render :show
    end
  end
  private
    def user_params
      params.require(:user).permit(:name, :password)
    end
end
