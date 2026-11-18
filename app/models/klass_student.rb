class KlassStudent < ApplicationRecord
  include AASM

  belongs_to :semester_klass
  belongs_to :student
  has_many :attendances, dependent: :destroy

  enum :status, [ :out, :in, :transfer ]

  aasm column: :status, enum: true do
    state :in, initial: true
    state :out
    state :transfer

    event :mark_out do
      transitions from: [ :in, :transfer ], to: :out
    end

    event :mark_transfer do
      transitions from: [ :in, :out ], to: :transfer
    end
  end

  def another_semester_klasses(semester_id)
    SemesterKlass
      .joins(:klass_students)
      .where(
        semester_id: semester_id,
        campuse_id: semester_klass.campuse_id,
      )
  end
end
