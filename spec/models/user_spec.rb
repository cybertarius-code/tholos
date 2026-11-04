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
end
