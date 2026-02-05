class GradeSubject < ApplicationRecord
  belongs_to :school
  belongs_to :grade
  belongs_to :subject

  def name
    "#{grade.name} #{subject.name}"
  end
end
