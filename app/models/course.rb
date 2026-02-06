class Course < ApplicationRecord
  belongs_to :klass
  has_many :attendances, dependent: :destroy

  def start!(date = Date.today)
    update!(start_date: date)
    klass.students.each do |student|
      attendances.find_or_create_by(student: student)
    end
  end

  def started?
    start_date.present?
  end
end
