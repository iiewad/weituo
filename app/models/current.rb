class Current < ActiveSupport::CurrentAttributes
  attribute :session, :campuse, :school, :semester
  delegate :user, to: :session, allow_nil: true
end
