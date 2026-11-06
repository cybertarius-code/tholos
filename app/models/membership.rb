class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :household

  validates :user_id, presence: true
  validates :user_id, uniqueness: { scope: :household_id }
  validates :household_id, presence: true

  enum :role, { admin: "admin", owner: "owner", member: "member" }, default: :owner
end
