require "rails_helper"

RSpec.describe Account do
  let(:household) { create(:household, base_currency: "EUR") }

  describe "#classification" do
    it "es activo para cuentas corrientes, de ahorro, efectivo, monedero, inversión y otras" do
      %w[ checking savings cash ewallet investment other ].each do |kind|
        account = build(:account, kind: kind)

        expect(account.classification).to eq(:asset), kind
        expect(account).not_to be_liability
      end
    end

    it "es pasivo para tarjetas de crédito y préstamos" do
      %w[ credit_card loan ].each do |kind|
        account = build(:account, kind: kind)

        expect(account.classification).to eq(:liability), kind
        expect(account).to be_liability
      end
    end
  end

  describe "importe inicial" do
    it "guarda el saldo inicial de un activo tal cual" do
      account = create(:account, household: household, opening_amount: "1250.00")

      expect(account.opening_balance_cents).to eq(125_000)
      expect(account.opening_balance).to eq(Money.new(125_000, "EUR"))
    end

    it "guarda la deuda inicial de una tarjeta en negativo" do
      account = create(:account, :credit_card, household: household, opening_amount: "300")

      expect(account.opening_balance_cents).to eq(-30_000)
      expect(account.reload.opening_amount).to eq("300.00")
    end

    it "guarda la deuda inicial de un préstamo en negativo" do
      account = create(:account, household: household, kind: "loan", opening_amount: "12000.50")

      expect(account.opening_balance_cents).to eq(-1_200_050)
    end

    it "aplica el signo según el tipo aunque el tipo se asigne después del importe" do
      account = described_class.new(household: household, name: "Visa", opening_date: Date.current, opening_amount: "300")
      account.kind = "credit_card"
      account.save!

      expect(account.opening_balance_cents).to eq(-30_000)
    end

    it "respeta un saldo negativo en una cuenta de activo (descubierto)" do
      account = create(:account, household: household, opening_amount: "-50")

      expect(account.opening_balance_cents).to eq(-5_000)
    end

    it "acepta coma decimal" do
      account = create(:account, household: household, opening_amount: "10,5")

      expect(account.opening_balance_cents).to eq(1_050)
    end

    it "rechaza un importe que no es un número" do
      account = build(:account, household: household, opening_amount: "mucho")

      expect(account).not_to be_valid
      expect(account.errors).to be_added(:opening_amount, :not_a_number)
    end
  end

  describe "validaciones" do
    it "exige nombre, tipo y fecha del saldo inicial" do
      account = described_class.new(household: household, name: " ", kind: nil, opening_date: nil)

      expect(account).not_to be_valid
      expect(account.errors).to include(:name, :kind, :opening_date)
    end

    it "rechaza un tipo desconocido" do
      account = build(:account, kind: "crypto")

      expect(account).not_to be_valid
      expect(account.errors).to include(:kind)
    end

    it "exige una moneda ISO 4217 existente" do
      expect(build(:account, currency: "EURO")).not_to be_valid
      expect(build(:account, currency: "XYZ")).not_to be_valid
      expect(build(:account, currency: "usd")).to be_valid
    end

    it "toma por defecto la moneda base del hogar" do
      household = create(:household, base_currency: "USD")
      account = create(:account, household: household, currency: nil)

      expect(account.currency).to eq("USD")
    end
  end

  describe "moneda inmutable con movimientos" do
    let(:account) { create(:account, household: household) }

    it "permite cambiar la moneda sin movimientos" do
      expect(account.update(currency: "USD")).to be(true)
    end

    it "impide cambiar la moneda si la cuenta tiene movimientos" do
      allow(account).to receive(:movements?).and_return(true)

      expect(account.update(currency: "USD")).to be(false)
      expect(account.errors).to be_added(:currency, :locked)
    end
  end

  describe "cierre y reapertura" do
    it "cierra y reabre la cuenta" do
      account = create(:account, household: household)

      account.close!
      expect(account.reload).to be_closed

      account.reopen!
      expect(account.reload).to be_open
    end

    it "deja de ofrecer las cuentas cerradas" do
      open_account = create(:account, household: household)
      create(:account, :closed, household: household)

      expect(household.accounts.open).to contain_exactly(open_account)
    end
  end

  describe "borrado" do
    it "se borra si no tiene movimientos" do
      account = create(:account, household: household)

      expect(account.destroy).to be_truthy
      expect(described_class.exists?(account.id)).to be(false)
    end

    it "no se borra si tiene movimientos" do
      account = create(:account, household: household)
      allow(account).to receive(:movements?).and_return(true)

      expect(account.destroy).to be(false)
      expect(account.errors).to be_added(:base, :has_movements)
      expect(described_class.exists?(account.id)).to be(true)
    end
  end
end
