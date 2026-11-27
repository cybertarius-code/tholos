# Un extracto bancario cargado (US-0113, ADR-0017). Sus filas no cuentan en el
# saldo ni en los informes hasta confirmarlo (Imports::Commit).
class Import < ApplicationRecord
  belongs_to :household
  belongs_to :account
  has_many :rows, -> { order(:line) }, class_name: "ImportRow", inverse_of: :import, dependent: :delete_all

  enum :status, { staged: "staged", confirmed: "confirmed" }, default: :staged, validate: true

  validate :account_in_household

  private
    def account_in_household
      errors.add(:account, :invalid) if account && account.household_id != household_id
    end
end
