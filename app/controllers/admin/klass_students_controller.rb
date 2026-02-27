class Admin::KlassStudentsController < AdminController
  def out
    @klass = Klass.find(params[:klass_id])
    @klass_student = @klass.klass_students.find(params[:id])
    @klass_student.send("mark_#{params[:status]}!", params[:out_course_id])
    redirect_to admin_klass_path(@klass), notice: "操作成功"
  end

  def destroy
    @sk = SemesterKlass.find(params[:semester_klass_id])
    @klass_student = @sk.klass_students.find(params[:id])
    @klass_student.destroy
  redirect_to admin_semester_klass_path(@sk), notice: "删除成功"
  end
end