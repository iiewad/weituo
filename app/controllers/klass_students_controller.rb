class KlassStudentsController < AdminController
  def out
    @klass = Klass.find(params[:klass_id])
    @klass_student = @klass.klass_students.find(params[:id])
    @klass_student.send("mark_#{params[:status]}!", params[:out_course_id])
    redirect_to admin_klass_path(@klass), notice: "操作成功"
  end
end
