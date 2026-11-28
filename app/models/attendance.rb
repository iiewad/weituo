class Attendance < ApplicationRecord
  include AASM
  belongs_to :course
  belongs_to :klass_student
  belongs_to :marked_by, class_name: "User", optional: true
  # 转出目标班；用于在原班提示学员去哪个班反向转出回来
  belongs_to :transfer_target_klass, class_name: "SemesterKlass", optional: true
  enum :status, [ :absent, :normal, :filled, :personal_leave, :sick_leave, :quit, :transfer, :transfer_in ]
  # 校验一个学员一个课程只能有一个考勤记录
  validates :klass_student_id, uniqueness: { scope: :course_id }
  # 只有已开课课次才有考勤；所有事件统一加守卫，防止异常数据绕过界面直接改写
  STARTED_GUARD = -> { course.started? }
  aasm column: :status do
    state :absent
    state :normal, initial: true
    state :filled
    state :personal_leave
    state :sick_leave
    state :quit
    state :transfer
    # 转入：目标班入班课次之前的课次标记，表示该课次学员尚未转入本班、未在本班就读。
    # 自动生成的转入行（课次早于入班课次）只读——不声明任何进出它的迁移，所有 mark_* 的 from 都不含它；
    # 只有在考勤卡里手动标记的转入行可以「恢复正常」，见 mark_transfer_in / manual_transfer_in?。
    state :transfer_in

    # 恢复正常：纠正误点的缺课 / 请假 / 补课，以及撤销手动标记的转入 / 转出；
    # 退课走「重新加入」，真实转出不可撤销
    event :mark_normal do
      transitions from: [ :absent, :personal_leave, :sick_leave, :filled ], to: :normal, guard: STARTED_GUARD
      transitions from: [ :transfer_in ], to: :normal, guard: :manual_transfer_in_started?
      transitions from: [ :transfer ], to: :normal, guard: :manual_transfer_out_started?,
        after: -> { self.manual_transfer_out = false }
    end

    # 手动标记为转入：学员实际是从之后的课次才进入本班，入班前已开课的课次不该记正常 / 缺课 / 请假。
    # 只改当前考勤行，不改报名状态与入班课次，也不级联其它课次。
    event :mark_transfer_in do
      transitions from: [ :absent, :normal, :personal_leave, :sick_leave, :filled ], to: :transfer_in, guard: STARTED_GUARD
    end

    # 手动标记为转出：学员本课次已不在本班就读，但报名仍在班。
    # 只改当前考勤行，不改报名状态，也不级联其它课次；与真实转出（mark_transfer）不同，可「恢复正常」撤销。
    event :mark_transfer_out do
      transitions from: [ :absent, :normal, :personal_leave, :sick_leave, :filled ], to: :transfer,
        guard: STARTED_GUARD, after: -> { self.manual_transfer_out = true }
    end

    event :mark_personal_leave do
      transitions from: [ :absent, :normal, :filled ], to: :personal_leave, guard: STARTED_GUARD
    end

    event :mark_absent do
      transitions from: [ :normal, :filled ], to: :absent, guard: STARTED_GUARD
    end

    event :mark_sick_leave do
      transitions from: [ :absent, :normal, :filled ], to: :sick_leave, guard: STARTED_GUARD
    end

    event :mark_rejoin do
      after do
        # 从当前课次起恢复在班，之前缺的课保留退课历史
        klass_student.reinstate!
      end
      transitions from: [ :quit ], to: :normal, guard: STARTED_GUARD
    end

    # 补课销假：只针对缺课/请假后补课。退课/转出学员回来上课应走「重新加入」，
    # 否则考勤记为补课但报名仍是 out/transfer，后续课次继续生成退/转状态。
    event :mark_filled do
      transitions from: [ :absent, :personal_leave, :sick_leave ], to: :filled, guard: STARTED_GUARD
    end

    event :mark_quit do
      after do
        # 报名可能已归档（历史数据 / 并发移出），取不到时不阻塞考勤级联
        ks = KlassStudent.active.find_by(
          semester_klass_id: course.semester_klass_id,
          student_id: klass_student.student_id
        )
        ks.mark_out! if ks&.in?
        # 只同步已开课课次；未开课课次等开课时再按报名状态生成
        course.semester_klass.courses.where("seq > ? AND start_date IS NOT NULL", course.seq).each do |c|
          attendance = c.attendances.find_or_create_by!(klass_student: klass_student)
          attendance.update!(status: "quit")
        end
      end
      transitions from: [ :absent, :normal, :personal_leave, :sick_leave, :filled ], to: :quit, guard: STARTED_GUARD
    end

    event :mark_transfer do
      after do
        # 报名可能已归档（历史数据 / 并发移出），取不到时不阻塞考勤级联
        ks = KlassStudent.active.find_by(
          semester_klass_id: course.semester_klass_id,
          student_id: klass_student.student_id
        )
        ks.mark_transfer! if ks && ks.status.in?([ "in", "out" ])
        # 只同步已开课课次；未开课课次等开课时再按报名状态生成
        course.semester_klass.courses.where("seq > ? AND start_date IS NOT NULL", course.seq).each do |c|
          attendance = c.attendances.find_or_create_by!(klass_student: klass_student)
          # 真实转出覆盖此前的手动标记，级联行不再可「恢复正常」
          attendance.update!(status: "transfer", manual_transfer_out: false)
        end
      end
      transitions from: [ :absent, :normal, :personal_leave, :sick_leave, :quit, :filled ], to: :transfer, guard: STARTED_GUARD
    end
  end

  # 是否为考勤卡里手动标记的转入行。自动生成的转入行一定早于入班课次（transfer_in_seq，
  # 由 join_klass 记录），其余转入行只能是手动标记的。
  def manual_transfer_in?
    transfer_in? && (klass_student.transfer_in_seq.nil? || course.seq >= klass_student.transfer_in_seq)
  end

  # mark_normal 撤销手动转入的守卫
  def manual_transfer_in_started?
    course.started? && manual_transfer_in?
  end

  # 是否为考勤卡里手动标记的转出行：报名仍在班，只把这一格标成转出，可「恢复正常」。
  # 真实转出（转出抽屉 / mark_transfer 级联）由报名状态驱动，不置此标记。
  def manual_transfer_out?
    transfer? && self[:manual_transfer_out]
  end

  # mark_normal 撤销手动转出的守卫
  def manual_transfer_out_started?
    course.started? && manual_transfer_out?
  end

  # 考勤状态展示：单字用于密集矩阵、全称用于悬停与图例、color 配合 badge-soft 柔和底。
  # 按语义分组：到课(success) / 请假(warning) / 缺课(error) / 退转(neutral)。
  STATUS_META = {
    "normal"         => { label: "√", name: "正常", color: "success" },
    "filled"         => { label: "补", name: "补课", color: "success" },
    "absent"         => { label: "缺", name: "缺课", color: "error" },
    "personal_leave" => { label: "事", name: "事假", color: "warning" },
    "sick_leave"     => { label: "病", name: "病假", color: "warning" },
    "quit"           => { label: "退", name: "退课", color: "neutral" },
    "transfer"       => { label: "转", name: "转出", color: "neutral" },
    "transfer_in"    => { label: "入", name: "转入", color: "neutral" }
  }.freeze

  def status_meta
    STATUS_META[status] || {}
  end

  def badge_class
    status_meta[:color] || "ghost"
  end

  def status_label
    status_meta[:label] || "—"
  end

  def status_name
    status_meta[:name] || "未录入"
  end
end
