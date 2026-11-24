module TransfersHelper
  # Cuentas abiertas; al editar, también las de los dos lados aunque estén cerradas
  def transfer_account_options(transfer)
    current_ids = [ transfer.outflow&.account_id, transfer.inflow&.account_id ].compact
    Current.household.accounts.ordered.to_a
      .select { |account| account.open? || current_ids.include?(account.id) }
      .map { |account| [ "#{account.name} (#{account.currency})", account.id ] }
  end
end
