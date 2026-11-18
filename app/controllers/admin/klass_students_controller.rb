class Admin::KlassStudentsController < AdminController
  def destroy
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    @klass_student = @sk.klass_students.find(params[:id])
    @klass_student.archive!
    redirect_to admin_semester_klass_path(@sk), notice: "已移出班级，历史考勤已保留"
  end

  def restore
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    @klass_student = @sk.all_klass_students.find(params[:id])
    @klass_student.restore!
    redirect_to admin_semester_klass_path(@sk), notice: "已恢复到班级"
  end
end
