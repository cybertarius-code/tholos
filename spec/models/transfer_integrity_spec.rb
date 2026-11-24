require "rails_helper"

# Lo que garantiza la BD aunque se salte el modelo (ADR-0004, ADR-0014 A)
RSpec.describe Transfer, "database integrity" do
  let(:household) { create(:household) }
  let(:checking) { create(:account, household: household) }
  let(:savings) { create(:account, household: household) }
  let(:transfer) do
    described_class.record!(household: household, from: checking, to: savings, amount_cents: 30_000, date: Date.new(2026, 11, 20))
  end

  def insert_leg(overrides = {})
    Transaction.insert!(transfer.inflow.attributes.except("id", "created_at", "updated_at").merge(overrides))
  end

  it "rechaza un tercer lado del mismo signo (transactions_un_lado_por_signo)" do
    expect { insert_leg("amount_cents" => 100) }
      .to raise_error(ActiveRecord::RecordNotUnique, /transactions_un_lado_por_signo/)
  end

  it "rechaza un lado con categoría (transactions_un_solo_tipo)" do
    category = create(:category, household: household)

    expect { transfer.inflow.update_column(:category_id, category.id) }
      .to raise_error(ActiveRecord::CheckViolation, /transactions_un_solo_tipo/)
  end

  # PostgreSQL 17 da ForeignKeyViolation y 18 RestrictViolation: se comprueba la tabla
  it "no deja borrar por SQL una transferencia con lados vivos (RESTRICT)" do
    expect { described_class.where(id: transfer.id).delete_all }
      .to raise_error(ActiveRecord::StatementInvalid, /"transfers"/)
  end
end
