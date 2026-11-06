class Household < ApplicationRecord
  has_many :memberships
  has_many :users, through: :memberships

  validates :name, presence: true
  validates :base_currency, presence: true, format: { with: /\A[A-Z]{3}\z/, message: "must be a valid ISO 4217 currency code" }
end
