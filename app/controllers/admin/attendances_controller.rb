class Admin::AttendancesController < AdminController
  def mark
    @klass = Klass.find(params[:klass_id])
    @attendance = Attendance.find(params[:id])
    @attendance.send("mark_#{params[:status]}!")
    redirect_to admin_klass_path(@klass), notice: "考勤已更新"
  end
end
