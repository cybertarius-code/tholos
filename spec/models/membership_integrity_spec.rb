require "rails_helper"

RSpec.describe Membership, "database integrity" do
  let(:user)      { create(:user) }
  let(:household) { create(:household) }

  describe "índice único [user_id, household_id]" do
    before { described_class.create!(user: user, household: household, role: "owner") }

    it "lanza RecordNotUnique con save(validate: false)" do
      duplicate = described_class.new(user: user, household: household)

      expect { duplicate.save(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "lanza RecordNotUnique con insert!" do
      expect {
        described_class.insert!({ user_id: user.id, household_id: household.id })
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "permite el mismo usuario en otro household" do
      other = create(:household)

      expect { described_class.create!(user: user, household: other) }
        .not_to raise_error
    end
  end

  describe "NOT NULL" do
    it "rechaza user_id nulo" do
      membership = described_class.new(user: nil, household: household)

      expect { membership.save(validate: false) }
        .to raise_error(ActiveRecord::NotNullViolation)
    end

    it "rechaza household_id nulo" do
      membership = described_class.new(user: user, household: nil)

      expect { membership.save(validate: false) }
        .to raise_error(ActiveRecord::NotNullViolation)
    end

    it "rechaza role nulo (el default solo aplica si no se asigna)" do
      membership = described_class.new(user: user, household: household, role: nil)

      expect { membership.save(validate: false) }
        .to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe "claves foráneas" do
    it "rechaza un user_id inexistente" do
      membership = described_class.new(user_id: 0, household: household)

      expect { membership.save(validate: false) }
        .to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "rechaza un household_id inexistente" do
      membership = described_class.new(user: user, household_id: 0)

      expect { membership.save(validate: false) }
        .to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
