class Admin::AttendancesController < AdminController
  def mark
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    @course = @sk.courses.find(params[:course_id])
    @attendance = @course.attendances.find(params[:id])
    mark_status(@attendance, params[:status])
    redirect_to admin_semester_klass_path(@sk), notice: "考勤已更新"
  end

  private
    def mark_status(attendance, status)
      case status
      when "absent" then attendance.mark_absent!
      when "personal_leave" then attendance.mark_personal_leave!
      when "sick_leave" then attendance.mark_sick_leave!
      when "filled" then attendance.mark_filled!
      when "quit" then attendance.mark_quit!
      when "transfer" then attendance.mark_transfer!
      when "rejoin" then attendance.mark_rejoin!
      end
    end
end
