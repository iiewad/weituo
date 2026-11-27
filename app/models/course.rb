class Course < ApplicationRecord
  belongs_to :semester_klass
  has_many :attendances, dependent: :destroy

  def start!(date = Date.today)
    transaction do
      # 锁定课次行：并发开同一课次时串行化，避免重复插入考勤撞唯一索引
      lock!
      return false if started? || !previous_courses_started?

      update!(start_date: date)
      semester_klass.klass_students.find_each do |ks|
        attendance = attendances.find_or_create_by!(klass_student_id: ks.id)
        # 退课 / 转出学员继续留在班级，后续开课沿用其报名状态生成对应考勤
        if ks.status == "out"
          attendance.update!(status: "quit")
        elsif ks.status == "transfer"
          attendance.update!(status: "transfer")
        elsif ks.status == "in" && ks.transfer_in_seq && seq < ks.transfer_in_seq
          # 转入学员入班课次之前的课次后补开课时标记「转入」；已有真实考勤保留，只改缺口默认行
          attendance.update!(status: "transfer_in") if attendance.previously_new_record?
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
