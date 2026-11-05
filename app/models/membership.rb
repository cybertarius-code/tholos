class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :household

  validates :user_id, presence: true
  validates :household_id, presence: true

  enum :role, [ admin: 0, owner: 1, member: 2 ],
end
