class PasswordsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: "操作过于频繁，请稍后再试。" }

  # 本项目以账号名登录，users 表没有邮箱列，也不提供邮件重置能力。
  # 统一给出不泄露账号是否存在的提示；实际重置由管理员在「用户管理」中完成。
  def new
  end

  def create
    redirect_to new_session_path, notice: "如需重置密码，请联系管理员。"
  end

  def edit
    redirect_to new_password_path, alert: "重置链接无效或已过期，请联系管理员。"
  end

  def update
    redirect_to new_password_path, alert: "重置链接无效或已过期，请联系管理员。"
  end
end
