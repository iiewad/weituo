class Admin::KlassStudentsController < AdminController
  def destroy
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    @klass_student = @sk.klass_students.find(params[:id])
    @klass_student.archive!
    redirect_to admin_semester_klass_path(@sk), notice: "已移出班级，历史考勤已保留"
  end

  # 考勤表勾选后批量移出，历史考勤保留
  def remove_batch
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    klass_students = @sk.klass_students.where(id: params[:ids]).to_a
    if klass_students.empty?
      redirect_to admin_semester_klass_path(@sk), alert: "请选择要移出的学员"
      return
    end

    klass_students.each(&:archive!)
    redirect_to admin_semester_klass_path(@sk), notice: "已移出 #{klass_students.size} 名学员，历史考勤已保留"
  end

  def restore
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    @klass_student = @sk.all_klass_students.find(params[:id])
    @klass_student.restore!
    redirect_to admin_semester_klass_path(@sk), notice: "已恢复到班级"
  end

  # 撤销退课 / 转出，恢复为在班
  def reinstate
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    @klass_student = @sk.klass_students.find(params[:id])
    @klass_student.reinstate!
    redirect_to admin_semester_klass_path(@sk),
      notice: "已撤销 #{@klass_student.student.identity_label} 的退课/转出"
  end
end
