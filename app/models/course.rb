class Course < ApplicationRecord
  belongs_to :semester_klass
  has_many :attendances, dependent: :destroy

  def start!(date = Date.today)
    return false if started? || !previous_courses_started?

    transaction do
      update!(start_date: date)
      semester_klass.klass_students.find_each do |ks|
        attendance = attendances.find_or_create_by(klass_student_id: ks.id)
        # 退课 / 转出学员继续留在班级，后续开课沿用其报名状态生成对应考勤
        case ks.status
        when "out"      then attendance.update!(status: "quit")
        when "transfer" then attendance.update!(status: "transfer")
        end
      end
    end
    true
  end

  def started?
    start_date.present?
  end

  # 开课必须按课次顺序：前面仍有未开课课次时不能跳着开
  def previous_courses_started?
    semester_klass.courses.where("seq < ?", seq).where(start_date: nil).none?
  end
end
