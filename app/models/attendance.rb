class Attendance < ApplicationRecord
  belongs_to :course
  belongs_to :student
  enum :status, [ :absent, :present ]
end
