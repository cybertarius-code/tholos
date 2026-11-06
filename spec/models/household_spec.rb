require "rails_helper"

RSpec.describe Household, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      household = Household.new(name: "Test Household", base_currency: "USD")
      expect(household).to be_valid
    end

    it "is not valid without a name" do
      household = Household.new(base_currency: "USD")
      expect(household).not_to be_valid
    end

    it "is not valid with an invalid base currency" do
      household = Household.new(name: "Test Household", base_currency: "INVALID")
      expect(household).not_to be_valid
    end
  end
end
