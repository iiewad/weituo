class Admin::AttendancesController < AdminController
  include KlassDetailContext

  # 可直接从考勤格切换的状态；转出必须走 #transfer 并选择目标班级。
  # transfer_in / transfer_out 是手动标记的转入 / 转出（只改当前考勤行，不改报名），
  # 自动生成的转入行与真实转出行由模型守卫拒绝改写。
  MARKABLE_STATUSES = %w[normal absent personal_leave sick_leave filled quit rejoin transfer_in transfer_out].freeze
  # 只改当前考勤行的状态走行级流式替换；退课 / 重新加入会级联报名与花名册，仍整体刷新
  STREAMABLE_STATUSES = (MARKABLE_STATUSES - %w[quit rejoin]).freeze
  STATUS_LABELS = Attendance::STATUS_META.transform_values { |meta| meta[:name] }
    .merge("rejoin" => "重新加入", "transfer_out" => "标记为转出").freeze

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

    unless @course.started?
      redirect_to admin_semester_klass_path(@sk), alert: "该课次尚未开课，无法修改考勤"
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
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_semester_klass_path(@sk),
        alert: "学员报名记录已变更，请刷新后重试"
      return
    end

    respond_to do |format|
      format.html { redirect_to admin_semester_klass_path(@sk), notice: "考勤已更新" }

      format.turbo_stream do
        if STREAMABLE_STATUSES.include?(status)
          set_klass_row_context
          ks = @klass_students.find { |klass_student| klass_student.id == @attendance.klass_student_id }
        end

        if ks
          render turbo_stream: [
            turbo_stream.replace(ks, partial: "admin/semester_klasses/attendance_row", locals: { ks: ks }),
            turbo_stream.update("flash", partial: "admin/shared/alert")
          ]
        else
          redirect_to admin_semester_klass_path(@sk), notice: "考勤已更新"
        end
      end
    end
  end

  # 转出引导：把学员转出当前班的同时加入目标班，保留原班考勤历史。
  def transfer
    @sk = campuse_semester_klasses.find(params[:semester_klass_id])
    @course = @sk.courses.find(params[:course_id])
    @attendance = @course.attendances.find(params[:id])
    @student = @attendance.klass_student.student

    unless @course.started?
      redirect_to admin_semester_klass_path(@sk), alert: "该课次尚未开课，无法转出"
      return
    end

    target = transfer_target_klasses.find_by(id: params[:target_semester_klass_id])

    if target.blank?
      redirect_to admin_semester_klass_path(@sk), alert: "请选择要转入的班级"
      return
    end
    # 报名为 transfer 的目标班允许转入：学员已在原班转出，反向转出即可回班
    existing_enrollment = KlassStudent.active.find_by(semester_klass_id: target.id, student_id: @student.id)
    if existing_enrollment&.in?
      redirect_to admin_semester_klass_path(@sk), alert: "#{@student.identity_label} 已在 #{target.name} 中"
      return
    end
    if existing_enrollment&.out?
      redirect_to admin_semester_klass_path(@sk),
        alert: "#{@student.identity_label} 曾在 #{target.name} 退课，请到该班点「重新加入」"
      return
    end
    unless @attendance.may_mark_transfer?
      redirect_to admin_semester_klass_path(@sk), alert: "当前考勤状态无法转出"
      return
    end

    # 入班课次按源班转出课次对齐，之前课次不补缺课，统一标记「转入」（源班考勤保留在源班）
    entry_seq = join_course_seq_for(target)
    if entry_seq.nil?
      redirect_to admin_semester_klass_path(@sk), alert: "#{target.name} 课程已全部开始，无法转入"
      return
    end

    Attendance.transaction do
      @attendance.mark_transfer!
      # 记录目标班，供原班提示学员去哪个班反向转出回来
      @attendance.update!(marked_by: Current.user, transfer_target_klass_id: target.id)
      # 转入目标班：记录来源班与入班课次，入班前已开课次标记「转入」（源班考勤保留在源班）
      @student.join_klass(target, course_seq: entry_seq, mark_previous_absent: false, reinstate: true, transfer_from: @sk)
      @student.mark_transferred_in_attendances(target, before_seq: entry_seq)
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

    # 入班课次按源班转出课次对齐：取「源班转出课次 + 1」与「目标班首个未开课课次」的较大者，
    # 目标班后补开课的入班前课次由 Course#start! 标记「转入」；对齐课次不存在（目标班课次更少）
    # 时退回首个未开课课次；没有未开课课次（已结课）时返回 nil，不允许转入
    def join_course_seq_for(target)
      first_unstarted = target.courses.where(start_date: nil).minimum(:seq)
      return nil if first_unstarted.nil?

      aligned = @course.seq + 1
      aligned > first_unstarted && target.courses.exists?(seq: aligned) ? aligned : first_unstarted
    end
end
