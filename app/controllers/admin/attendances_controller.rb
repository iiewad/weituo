class Admin::AttendancesController < AdminController
  # 可直接从考勤格切换的状态；转出必须走 #transfer 并选择目标班级
  MARKABLE_STATUSES = %w[absent personal_leave sick_leave filled quit rejoin].freeze
  STATUS_LABELS = Attendance::STATUS_META.transform_values { |meta| meta[:name] }
    .merge("rejoin" => "重新加入").freeze

  def mark
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    @course = @sk.courses.find(params[:course_id])
    @attendance = @course.attendances.find(params[:id])
    status = params[:status].to_s

    unless MARKABLE_STATUSES.include?(status)
      message = status == "transfer" ? "转出请在转出抽屉中选择目标班级" : "未知的考勤状态"
      redirect_to admin_semester_klass_path(@sk), alert: message
      return
    end

    # 状态迁移级联本就在 AASM 事务内；这里把操作人记录也纳入同一事务
    begin
      Attendance.transaction do
        @attendance.public_send("mark_#{status}!")
        @attendance.update!(marked_by: Current.user)
      end
    rescue AASM::InvalidTransition
      redirect_to admin_semester_klass_path(@sk),
        alert: "当前考勤状态无法改为「#{STATUS_LABELS.fetch(status, status)}」"
      return
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
end
