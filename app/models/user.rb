class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :households, through: :memberships

  validates :email_address, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 12 }, if: -> { new_record? || !password.nil? }
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def self.create_with_household!(email:, password:, household_name: nil)
    transaction do
      user = create!(email_address: email, password: password)
      # shortcut: users no tiene columna de nombre; se usa la parte local del email hasta que exista
      household = Household.create!(name: household_name.presence || "#{I18n.t('households.new.title')} #{user.email_address.split('@').first.capitalize}")
      Membership.create!(user: user, household: household, role: :owner)
      user
    end
  end
end
