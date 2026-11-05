class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :households, through: :memberships

  validates :email_address, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 12 }, if: -> { new_record? || !password.nil? }
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def self.create_with_household!(:email, :password)
    transaction do
      user = User.create!(email_address: email, password: password)
      Membership.create!(user: user, household: Current.household, role: :owner)
      user
    end

  end
end
