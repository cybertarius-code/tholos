require "rails_helper"

RSpec.describe Transaction, "database integrity" do
  let(:household) { create(:household) }
  let(:account) { create(:account, household: household, currency: "EUR") }
  let(:transaction) { create(:transaction, account: account) }

  def insert(overrides = {})
    described_class.insert!(transaction.attributes.except("id", "created_at", "updated_at").merge(overrides))
  end

  it "CHECK: rechaza un importe cero" do
    expect { transaction.update_column(:amount_cents, 0) }
      .to raise_error(ActiveRecord::CheckViolation, /transactions_importe_no_cero/)
  end

  it "CHECK: rechaza un estado fuera del enum" do
    expect { transaction.update_column(:status, "void") }
      .to raise_error(ActiveRecord::CheckViolation, /transactions_status_check/)
  end

  it "CHECK transactions_un_solo_tipo: ajuste y categoría a la vez" do
    category = create(:category, household: household)

    expect { insert("adjustment" => true, "category_id" => category.id) }
      .to raise_error(ActiveRecord::CheckViolation, /transactions_un_solo_tipo/)
  end

  it "FK compuesta: la cuenta debe ser del mismo hogar" do
    expect { transaction.update_column(:household_id, create(:household).id) }
      .to raise_error(ActiveRecord::InvalidForeignKey, /transactions_account_household_fk/)
  end

  it "FK compuesta: la moneda debe ser la de la cuenta" do
    expect { transaction.update_column(:currency, "USD") }
      .to raise_error(ActiveRecord::InvalidForeignKey, /transactions_account_currency_fk/)
  end

  it "FK compuesta: la categoría debe ser del mismo hogar" do
    expect { transaction.update_column(:category_id, create(:category).id) }
      .to raise_error(ActiveRecord::InvalidForeignKey, /transactions_category_household_fk/)
  end

  it "índice transactions_un_lado_por_signo: como mucho una salida por transferencia" do
    transfer_id = ActiveRecord::Base.connection.insert(
      "INSERT INTO transfers (household_id, created_at, updated_at) VALUES (#{household.id}, now(), now())"
    )
    insert("transfer_id" => transfer_id, "amount_cents" => -100)
    insert("transfer_id" => transfer_id, "amount_cents" => 100)

    expect { insert("transfer_id" => transfer_id, "amount_cents" => -50) }
      .to raise_error(ActiveRecord::RecordNotUnique, /transactions_un_lado_por_signo/)
  end

  describe "ON DELETE RESTRICT" do
    let(:category) { create(:category, household: household) }

    before { create(:transaction, account: account, category: category) }

    it "no se borra una cuenta con movimientos" do
      expect { Account.where(id: account.id).delete_all }.to raise_error(ActiveRecord::StatementInvalid, /RestrictViolation/)
    end

    it "no se borra una categoría con movimientos" do
      expect { Category.where(id: category.id).delete_all }.to raise_error(ActiveRecord::StatementInvalid, /RestrictViolation/)
    end
  end

  describe "violaciones convertidas en errores de validación" do
    it "un importe cero que se salta Rails da el error traducido" do
      zero = build(:transaction, account: account, amount_cents: 0)

      expect(zero.save(validate: false)).to be(false)
      expect(zero.errors).to be_added(:amount, :cannot_be_zero)
    end

    it "cambiar la moneda de una cuenta con movimientos lo impide la BD aunque se salte Rails" do
      transaction
      reloaded = Account.find(account.id)
      reloaded.currency = "USD"

      expect(reloaded.save(validate: false)).to be(false)
      expect(reloaded.errors).to be_added(:currency, :locked)
    end
  end
end
