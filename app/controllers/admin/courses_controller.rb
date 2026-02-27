class Admin::CoursesController < AdminController
  def start
    @sk = SemesterKlass.find(params[:semester_klass_id])
    @course = @sk.courses.find(params[:id])
    @course.start!
    redirect_to admin_semester_klass_path(@sk), notice: "考勤已开始"
  end

  def insert_students
    course = Course.find(params[:id])
    @sk = SemesterKlass.where(
      campuse_id: Thread.current[:campuse].id,
    ).find(params[:semester_klass_id])
    text = params[:course][:students_text].split("\n").collect do |line|
      line.strip
      line + " #{course.seq}+"
    end
    @sk.add_students_by_text(text.join("\n"))
    redirect_to admin_semester_klass_path(@sk), notice: "学员添加成功"
  end

end
