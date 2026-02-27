class Attendance < ApplicationRecord
  include AASM
  belongs_to :course
  belongs_to :klass_student
  enum :status, [ :absent, :normal, :personal_leave, :sick_leave, :quit, :transfer ]
  # 校验一个学员一个课程只能有一个考勤记录
  validates :klass_student_id, uniqueness: { scope: :course_id }

  aasm column: :status do
    state :absent
    state :normal, initial: true
    state :personal_leave
    state :sick_leave
    state :quit
    state :transfer

    event :mark_personal_leave do
      transitions from: [ :absent, :normal ], to: :personal_leave, guard: -> { course.started? }
    end

    event :mark_absent do
      transitions from: :normal, to: :absent
    end

    event :mark_sick_leave do
      transitions from: [ :absent, :normal ], to: :sick_leave
    end

    # 补课销假
    event :mark_normal do
      transitions from: [ :absent, :personal_leave, :sick_leave ], to: :normal
    end

    event :mark_quit do
      after do
        ks = KlassStudent.find_by!(
          semester_klass_id: course.semester_klass_id,
          student_id: klass_student.student_id
        )
        ks.mark_out! if ks.status == "in"
        # 课程之后未开课的课程提前创建退课考勤记录
        course.semester_klass.courses.where("seq > ?", course.seq).each do |c|
          attendance = c.attendances.find_or_create_by!(klass_student: klass_student)
          attendance.update!(status: "quit")
        end
      end
      transitions from: [ :absent, :normal, :personal_leave, :sick_leave ], to: :quit
    end

    event :mark_transfer do
      after do
        ks = KlassStudent.find_by!(
          semester_klass_id: course.semester_klass_id,
          student_id: klass_student.student_id
        )
        ks.mark_out! if ks.status == "in"
        # 此课程之后的考勤，状态改为转出
        course.semester_klass.courses.where("seq > ?", course.seq).each do |c|
          attendance = c.attendances.find_or_create_by!(klass_student: klass_student)
          attendance.update!(status: "transfer")
        end
      end
      transitions from: [ :absent, :normal, :personal_leave, :sick_leave ], to: :transfer
    end
  end

  def badge_class
    case status
    when "absent"
      "primary"
    when "normal"
      "success"
    when "personal_leave"
      "warning"
    when "sick_leave"
      "danger"
    when "quit"
      "secondary"
    when "transfer"
      "info"
    end
  end

  def status_icon
    case status
    when "absent"
      "缺"
    when "normal"
      "✓"
    when "personal_leave"
      "事"
    when "sick_leave"
      "病"
    when "quit"
      "退"
    when "transfer"
      "转"
    end
  end
end
