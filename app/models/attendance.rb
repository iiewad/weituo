class Attendance < ApplicationRecord
  include AASM
  belongs_to :course
  belongs_to :klass_student
  belongs_to :marked_by, class_name: "User", optional: true
  # 转出目标班；撤销转出时据此把学员从目标班移出
  belongs_to :transfer_target_klass, class_name: "SemesterKlass", optional: true
  enum :status, [ :absent, :normal, :filled, :personal_leave, :sick_leave, :quit, :transfer ]
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

    # 恢复正常：纠正误点的缺课 / 请假 / 补课；退课 / 转出走「重新加入」
    event :mark_normal do
      transitions from: [ :absent, :personal_leave, :sick_leave, :filled ], to: :normal, guard: STARTED_GUARD
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
        # 从当前课次起恢复在班，之前缺的课保留退/转历史
        klass_student.reinstate!
      end
      transitions from: [ :quit, :transfer ], to: :normal, guard: STARTED_GUARD
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
        ks.mark_out! if ks && ks.status.in?([ "in", "transfer" ])
        # 只同步已开课课次；未开课课次等开课时再按报名状态生成
        course.semester_klass.courses.where("seq > ? AND start_date IS NOT NULL", course.seq).each do |c|
          attendance = c.attendances.find_or_create_by!(klass_student: klass_student)
          attendance.update!(status: "quit")
        end
      end
      transitions from: [ :absent, :normal, :personal_leave, :sick_leave, :filled, :transfer ], to: :quit, guard: STARTED_GUARD
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
          attendance.update!(status: "transfer")
        end
      end
      transitions from: [ :absent, :normal, :personal_leave, :sick_leave, :quit, :filled ], to: :transfer, guard: STARTED_GUARD
    end
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
    "transfer"       => { label: "转", name: "转出", color: "neutral" }
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
