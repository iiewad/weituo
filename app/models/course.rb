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

  # 修改已开课课次的开课日期：cascade 时把后面已开课的课次按「新日期 + 间隔 × 次序」顺延，
  # 未开课课次不受影响；考勤不按日期取数，改日期不影响任何考勤记录。
  def reschedule!(date, cascade: false, interval_days: 7)
    transaction do
      update!(start_date: date)
      next unless cascade

      later_started_courses.each_with_index do |course, index|
        course.update!(start_date: date + (index + 1) * interval_days)
      end
    end
  end

  def later_started_courses
    semester_klass.courses.where("seq > ?", seq).where.not(start_date: nil).order(:seq).to_a
  end

  # 开课必须按课次顺序：前面仍有未开课课次时不能跳着开
  def previous_courses_started?
    semester_klass.courses.where("seq < ?", seq).where(start_date: nil).none?
  end
end
