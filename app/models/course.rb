class Course < ApplicationRecord
  belongs_to :semester_klass
  has_many :attendances, dependent: :destroy

  def start!(date = Date.today)
    return if started?

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
  end

  def started?
    start_date.present?
  end
end
