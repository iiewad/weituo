class Course < ApplicationRecord
  belongs_to :semester_klass
  has_many :attendances, dependent: :destroy

  def start!(date = Date.today)
    update!(start_date: date)
    semester_klass.klass_students.each do |ks|
      attendances.find_or_create_by(student_id: ks.student_id)
    end
  end

  def started?
    start_date.present?
  end
end
