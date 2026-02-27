class Course < ApplicationRecord
  belongs_to :semester_klass
  has_many :attendances, dependent: :destroy

  def start!(date = Date.today)
    return if started?

    update!(start_date: date)
    semester_klass.klass_students.each do |ks|
      attendances.find_or_create_by(klass_student_id: ks.id)
    end
  end

  def started?
    start_date.present?
  end
end
