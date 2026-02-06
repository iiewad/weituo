class KlassStudent < ApplicationRecord
  include AASM

  belongs_to :klass
  belongs_to :student

  enum :status, [ :out, :in ]

  aasm column: :status, enum: true do
    state :in, initial: true
    state :out

    event :mark_out do
      transitions from: :in, to: :out
    end
  end
end
