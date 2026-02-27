class Admin::AttendancesController < AdminController
  def mark
    @sk = SemesterKlass.find(params[:semester_klass_id])
    @attendance = Attendance.find(params[:id])
    @attendance.send("mark_#{params[:status]}!")
    redirect_to admin_semester_klass_path(@sk), notice: "考勤已更新"
  end
end
