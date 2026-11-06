require 'rails_helper'

RSpec.describe User, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      user = User.new(email_address: "test@example.com", password: "password1234", password_confirmation: "password1234")
      expect(user).to be_valid
    end
    it "is not valid without an email address" do
      user = User.new(password: "password123", password_confirmation: "password123")
      expect(user).not_to be_valid
    end
    it "is not valid without a password" do
      user = User.new(email_address: "test@example.com")
      expect(user).not_to be_valid
    end
    it "is not valid with a short password" do
      user = User.new(email_address: "test@example.com", password: "pass", password_confirmation: "pass")
      expect(user).not_to be_valid
    end
  end

  describe ".create_with_household!" do
    it "crea el usuario, su hogar en EUR y la membresía owner" do
      user = User.create_with_household!(email: "Ana@Example.com", password: "password1234")

      membership = Membership.includes(:household).find_by!(user: user)
      expect(membership).to be_owner
      expect(membership.household).to have_attributes(name: "#{I18n.t('households.new.title')} Ana", base_currency: "EUR")
    end

    it "no deja registros huérfanos si falla un paso" do
      allow(Membership).to receive(:create!).and_raise(ActiveRecord::ActiveRecordError)

      expect {
        User.create_with_household!(email: "ana@example.com", password: "password1234")
      }.to raise_error(ActiveRecord::ActiveRecordError)
      expect([ User.count, Household.count ]).to eq([ 0, 0 ])
    end

    it "membresía owner se crea con el hogar correcto" do
      user = User.create_with_household!(email: "test@example.com", password: "password1234")
      membership = Membership.find_by(user: user)
      expect(membership).to be_owner
    end
  end
end
