require "rails_helper"

RSpec.describe Transaction do
  let(:household) { create(:household) }
  let(:account) { create(:account, household: household, name: "Corriente BBVA", currency: "EUR") }
  let(:food) { create(:category, household: household, name: "Alimentación") }
  let(:salary) { create(:category, :income, household: household, name: "Nómina") }

  def build_from_form(**attributes)
    household.transactions.new({ account_id: account.id, date: Date.new(2026, 11, 20), direction: "expense" }.merge(attributes))
  end

  describe "signo e importe del formulario" do
    it "guarda un gasto en negativo" do
      transaction = build_from_form(amount_input: "12,50", category_id: food.id, payee: "Mercadona")

      expect(transaction.save).to be(true)
      expect(transaction).to have_attributes(amount_cents: -1_250, currency: "EUR", status: "cleared")
    end

    it "guarda un ingreso en positivo" do
      transaction = build_from_form(direction: "income", amount_input: "2.000", category_id: salary.id)

      expect(transaction.save).to be(true)
      expect(transaction.amount_cents).to eq(200_000)
    end

    it "toma el valor absoluto: el signo lo pone la pestaña" do
      expect(build_from_form(amount_input: "-5").tap(&:save!).amount_cents).to eq(-500)
    end

    it "entiende la coma decimal, el punto de miles y el punto decimal" do
      {
        "12,50" => 1_250, "1.234,56" => 123_456, "12.5" => 1_250, "12.50" => 1_250,
        "1.234" => 123_400, "1.234.567" => 123_456_700, "0,01" => 1, "1 000,5" => 100_050
      }.each do |input, cents|
        expect(build_from_form(amount_input: input).tap(&:valid?).amount_cents.abs).to eq(cents), input
      end
    end

    it "redondea a céntimos" do
      expect(build_from_form(amount_input: "0,005").tap(&:valid?).amount_cents).to eq(-1)
    end

    it "muestra el importe guardado en positivo y con coma" do
      transaction = described_class.find(create(:transaction, account: account, amount_cents: -123_456).id)

      expect(transaction.amount_input).to eq("1234,56")
      expect(transaction.direction).to eq("expense")
    end

    it "admite un importe positivo en una categoría de gasto (devolución)" do
      transaction = build_from_form(direction: "income", amount_input: "10", category_id: food.id)

      expect(transaction.save).to be(true)
      expect(transaction.amount_cents).to eq(1_000)
    end
  end

  describe "importe cero o inválido" do
    it "rechaza un importe cero" do
      transaction = build_from_form(amount_input: "0,00")

      expect(transaction).not_to be_valid
      expect(transaction.errors).to be_added(:amount, :cannot_be_zero)
    end

    it "rechaza un importe vacío o que no es un número" do
      expect(build_from_form(amount_input: "").tap(&:valid?).errors).to be_added(:amount, :blank)
      expect(build_from_form(amount_input: "doce").tap(&:valid?).errors).to be_added(:amount, :not_a_number)
    end
  end

  describe "cuenta" do
    it "copia la moneda de la cuenta al crear" do
      usd = create(:account, household: household, currency: "USD")

      expect(build_from_form(account_id: usd.id, amount_input: "5").tap(&:save!).currency).to eq("USD")
    end

    it "rechaza una moneda distinta de la de la cuenta" do
      transaction = described_class.find(create(:transaction, account: account).id)
      transaction.currency = "USD"

      expect(transaction).not_to be_valid
      expect(transaction.errors).to be_added(:currency, :mismatch)
    end

    it "rechaza una cuenta cerrada en un movimiento nuevo" do
      account.close!

      transaction = build_from_form(amount_input: "5")
      expect(transaction).not_to be_valid
      expect(transaction.errors).to be_added(:account_id, :closed)
    end

    it "permite editar un movimiento de una cuenta que se cerró después" do
      transaction = described_class.find(create(:transaction, account: account).id)
      account.close!

      expect(transaction.update(payee: "Corregido")).to be(true)
    end

    it "rechaza una cuenta de otro hogar" do
      transaction = build_from_form(account_id: create(:account).id, amount_input: "5")

      expect(transaction).not_to be_valid
      expect(transaction.errors).to be_added(:account_id, :invalid)
    end
  end

  describe "categoría" do
    it "rechaza una categoría de otro hogar" do
      transaction = build_from_form(amount_input: "5", category_id: create(:category).id)

      expect(transaction).not_to be_valid
      expect(transaction.errors).to be_added(:category_id, :invalid)
    end

    it "rechaza una categoría archivada en un movimiento nuevo, pero la conserva al editar" do
      transaction = build_from_form(amount_input: "5", category_id: food.id).tap(&:save!)
      Category.find(food.id).archive!

      expect(described_class.find(transaction.id).update(payee: "Mercadona")).to be(true)
      expect(build_from_form(amount_input: "5", category_id: food.id)).not_to be_valid
    end

    it "sin categoría es válido" do
      expect(build_from_form(amount_input: "5")).to be_valid
    end
  end

  describe "un solo tipo (ADR-0014 A)" do
    it "rechaza un ajuste con categoría" do
      transaction = build_from_form(amount_input: "5", category_id: food.id, adjustment: true)

      expect(transaction).not_to be_valid
      expect(transaction.errors).to be_added(:base, :un_solo_tipo)
    end
  end

  describe "scopes" do
    it "income_and_expense excluye ajustes y transferencias" do
      normal = create(:transaction, account: account)
      create(:transaction, account: account, adjustment: true)

      expect(described_class.income_and_expense).to contain_exactly(normal)
    end
  end
end
