require "rails_helper"

RSpec.describe Account, "database integrity" do
  let(:account) { create(:account) }

  describe "CHECK de kind" do
    it "rechaza un kind fuera del enum" do
      expect { account.update_column(:kind, "crypto") }
        .to raise_error(ActiveRecord::StatementInvalid, /accounts_kind_check/)
    end
  end

  describe "CHECK de status" do
    it "rechaza un status fuera del enum" do
      expect { account.update_column(:status, "archived") }
        .to raise_error(ActiveRecord::StatementInvalid, /accounts_status_check/)
    end
  end

  describe "NOT NULL" do
    %i[ name kind currency opening_balance_cents opening_date status include_in_net_worth position ].each do |column|
      it "rechaza #{column} nulo" do
        expect { account.update_column(column, nil) }
          .to raise_error(ActiveRecord::NotNullViolation)
      end
    end
  end

  describe "clave foránea" do
    it "rechaza un household_id inexistente" do
      expect { account.update_column(:household_id, 0) }
        .to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
