class Admin::AttendancesController < AdminController
  def mark
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    @course = @sk.courses.find(params[:course_id])
    @attendance = @course.attendances.find(params[:id])
    # 状态迁移级联本就在 AASM 事务内；这里把操作人记录也纳入同一事务
    Attendance.transaction do
      mark_status(@attendance, params[:status])
      @attendance.update!(marked_by: Current.user)
    end
    redirect_to admin_semester_klass_path(@sk), notice: "考勤已更新"
  end

  # 转出引导：把学员转出当前班的同时加入目标班，保留原班考勤历史。
  def transfer
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    @course = @sk.courses.find(params[:course_id])
    @attendance = @course.attendances.find(params[:id])
    @student = @attendance.klass_student.student
    target = transfer_target_klasses.find_by(id: params[:target_semester_klass_id])

    if target.blank?
      redirect_to admin_semester_klass_path(@sk), alert: "请选择要转入的班级"
      return
    end
    if KlassStudent.exists?(semester_klass_id: target.id, student_id: @student.id)
      redirect_to admin_semester_klass_path(@sk), alert: "#{@student.identity_label} 已在 #{target.name} 中"
      return
    end
    unless @attendance.may_mark_transfer?
      redirect_to admin_semester_klass_path(@sk), alert: "当前考勤状态无法转出"
      return
    end

    Attendance.transaction do
      @attendance.mark_transfer!
      # 记录目标班，撤销转出时可据此把学员从目标班移出
      @attendance.update!(
        marked_by: Current.user,
        mark_at: (@attendance.mark_at || {}).merge("transfer_target_klass_id" => target.id)
      )
      @student.join_klass(target, course_seq: join_course_seq_for(target))
    end

    redirect_to admin_semester_klass_path(@sk),
      notice: "已将 #{@student.identity_label} 转出到 #{target.name}"
  end

  private
    # 只能转入同校区、同学期、同年级的其它班级
    def transfer_target_klasses
      SemesterKlass.where(
        campuse_id: @sk.campuse_id,
        semester_id: @sk.semester_id,
        grade_id: @sk.grade_id
      ).where.not(id: @sk.id)
    end

    # 转入后从目标班首个未开课课次开始；之前课次由 join_klass 补记为缺课
    def join_course_seq_for(target)
      first_open = target.courses.where(start_date: nil).minimum(:seq) || target.times.to_i
      [ first_open, 1 ].max
    end

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
