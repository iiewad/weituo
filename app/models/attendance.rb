class Attendance < ApplicationRecord
  include AASM
  belongs_to :course
  belongs_to :student
  enum :status, [ :absent, :normal, :personal_leave, :sick_leave ]

  aasm column: :status do
    state :absent
    state :normal, initial: true
    state :personal_leave
    state :sick_leave

    event :mark_personal_leave do
      transitions from: [ :absent, :normal ], to: :personal_leave
    end

    event :mark_absent do
      transitions from: :normal, to: :absent
    end

    event :mark_sick_leave do
      transitions from: [ :absent, :normal ], to: :sick_leave
    end

    # 补课销假
    event :mark_normal do
      transitions from: [ :absent, :personal_leave, :sick_leave ], to: :normal
    end
  end

  def status_icon
    case status
    when "absent"
      "❌"
    when "normal"
      "✅"
    when "personal_leave"
      "🕒"
    when "sick_leave"
      "🚑"
    end
  end
end
