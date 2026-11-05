class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true

  attribute :household
  delegate :memberships, to: :household, allow_nil: true
end
