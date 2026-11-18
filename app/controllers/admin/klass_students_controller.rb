class Admin::KlassStudentsController < AdminController
  def destroy
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    @klass_student = @sk.klass_students.find(params[:id])
    @klass_student.destroy
    redirect_to admin_semester_klass_path(@sk), notice: "删除成功"
  end
end
