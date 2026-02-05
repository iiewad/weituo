class KlassStudent < ApplicationRecord
  include AASM

  belongs_to :klass
  belongs_to :student

  enum :status, [ :quit, :active, :stop ]

  aasm column: :status, enum: true do
    state :active, initial: true
    state :quit
    state :stop

    event :quit do
      after do
        self.quit_date = Date.current if quit_date.blank?
      end
      transitions from: :active, to: :quit
    end

    event :stop do
      after do
        self.stop_date = Date.current if stop_date.blank?
      end
      transitions from: :active, to: :stop
    end
  end
end
