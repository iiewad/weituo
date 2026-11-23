class Attendance < ApplicationRecord
  include AASM
  belongs_to :course
  belongs_to :klass_student, -> { unscope(where: :archived_at) }
  belongs_to :marked_by, class_name: "User", optional: true
  enum :status, [ :absent, :normal, :filled, :personal_leave, :sick_leave, :quit, :transfer ]
  # 校验一个学员一个课程只能有一个考勤记录
  validates :klass_student_id, uniqueness: { scope: :course_id }

  store :mark_at, accessors: [ :absent_at, :personal_leave_at, :sick_leave_at, :quit_at, :transfer_at, :filled_at, :rejoin_at ]
  aasm column: :status do
    state :absent
    state :normal, initial: true
    state :filled
    state :personal_leave
    state :sick_leave
    state :quit
    state :transfer

    event :mark_personal_leave do
      before do
        self.personal_leave_at = Time.zone.now.iso8601
      end
      transitions from: [ :absent, :normal, :filled ], to: :personal_leave, guard: -> { course.started? }
    end

    event :mark_absent do
      before do
        self.absent_at = Time.zone.now.iso8601
      end
      transitions from: [ :normal, :filled ], to: :absent
    end

    event :mark_sick_leave do
      before do
        self.sick_leave_at = Time.zone.now.iso8601
      end
      transitions from: [ :absent, :normal, :filled ], to: :sick_leave
    end

    event :mark_rejoin do
      before do
        self.rejoin_at = Time.zone.now.iso8601
      end
      after do
        # 与班级页「撤销」共用 KlassStudent#reinstate! 的语义：只撤销最近一段连续退/转
        klass_student.reinstate!(attendance: self)
      end
      transitions from: [ :quit, :transfer ], to: :normal
    end

    # 补课销假
    event :mark_filled do
      before do
        self.absent_at = nil
        self.personal_leave_at = nil
        self.sick_leave_at = nil
        self.quit_at = nil
        self.transfer_at = nil
        self.filled_at = Time.zone.now.iso8601
      end
      transitions from: [ :absent, :personal_leave, :sick_leave, :quit, :transfer ], to: :filled
    end

    event :mark_quit do
      before do
        self.quit_at = Time.zone.now.iso8601
      end
      after do
        ks = KlassStudent.find_by!(
          semester_klass_id: course.semester_klass_id,
          student_id: klass_student.student_id
        )
        ks.mark_out! if ks.status.in?([ "in", "transfer" ])
        # 只同步已开课课次；未开课课次等开课时再按报名状态生成
        course.semester_klass.courses.where("seq > ? AND start_date IS NOT NULL", course.seq).each do |c|
          attendance = c.attendances.find_or_create_by!(klass_student: klass_student)
          attendance.update!(status: "quit")
        end
      end
      transitions from: [ :absent, :normal, :personal_leave, :sick_leave, :filled, :transfer ], to: :quit
    end

    event :mark_transfer do
      before do
        self.transfer_at = Time.zone.now.iso8601
      end
      after do
        ks = KlassStudent.find_by!(
          semester_klass_id: course.semester_klass_id,
          student_id: klass_student.student_id
        )
        ks.mark_transfer! if ks.status.in?([ "in", "out" ])
        # 只同步已开课课次；未开课课次等开课时再按报名状态生成
        course.semester_klass.courses.where("seq > ? AND start_date IS NOT NULL", course.seq).each do |c|
          attendance = c.attendances.find_or_create_by!(klass_student: klass_student)
          attendance.update!(status: "transfer")
        end
      end
      transitions from: [ :absent, :normal, :personal_leave, :sick_leave, :quit, :filled ], to: :transfer
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
