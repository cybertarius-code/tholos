class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  validates :email_address, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 12 }, if: -> { new_record? || !password.nil? }
  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
