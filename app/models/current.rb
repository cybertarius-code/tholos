class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :household

  delegate :user, to: :session, allow_nil: true

  # Membresía del usuario actual en el household actual
  def membership
    return unless user && household

    household.memberships.find_by(user: user)
  end

  # Todas las membresías del household (renombrado para que no se confunda)
  def household_memberships
    household ? household.memberships : Membership.none
  end
end
