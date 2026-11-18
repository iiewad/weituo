class Admin::CoursesController < AdminController
  def start
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    @course = @sk.courses.find(params[:id])
    @course.start!
    redirect_to admin_semester_klass_path(@sk), notice: "考勤已开始"
  end

  def insert_students
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    course = @sk.courses.find(params[:id])
    student_ids = Array(params[:student_ids]).reject(&:blank?)

    if student_ids.empty?
      redirect_to admin_semester_klass_path(@sk), alert: "请先选择要添加的学员"
      return
    end

    students = Student.where(id: student_ids, campuse_id: @sk.campuse_id, grade_id: @sk.grade_id)
      .where.not(id: @sk.klass_students.select(:student_id))
      .to_a

    if students.empty?
      redirect_to admin_semester_klass_path(@sk), alert: "所选学员已在班级中，无需重复添加"
      return
    end

    students.each { |student| student.join_klass(@sk, course_seq: course.seq) }
    redirect_to admin_semester_klass_path(@sk), notice: "已添加 #{students.size} 名学员"
  end
end
