require "rails_helper"

RSpec.describe Membership do
  let(:user)      { create(:user) }
  let(:household) { create(:household) }

  describe "validaciones" do
    it "no permite dos membresías del mismo usuario en el mismo hogar" do
      create(:membership, user: user, household: household)
      duplicate = build(:membership, user: user, household: household)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end
  end

  describe "rol" do
    it "es owner por defecto" do
      membership = described_class.new(user: user, household: household)

      expect(membership).to be_owner
    end
  end
end
