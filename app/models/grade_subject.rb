class GradeSubject < ApplicationRecord
  belongs_to :school
  belongs_to :grade
  belongs_to :subject
end
