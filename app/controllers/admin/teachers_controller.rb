class Admin::TeachersController < ApplicationController
  def index
    @teachers = Teacher.includes(:subject, :campuse).where(
      campuse_id: Thread.current[:campuse].id
    ).page(params[:page])
  end

  def update
    @teacher = Teacher.find(params[:id])
    @teacher.update(teacher_params)
    redirect_to admin_teachers_path, notice: "教师信息更新成功"
  end

  def create
    @teacher = Teacher.new(teacher_params)
    @teacher.save!
    redirect_to admin_teachers_path, notice: "教师信息创建成功"
  end

  private

  def teacher_params
    params.require(:teacher).permit(:name, :phone, :campuse_id, :subject_id)
  end
end
