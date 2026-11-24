require "rails_helper"

RSpec.describe Account, "saldos" do
  let(:account) { create(:account, opening_balance_cents: 10_000) }
  let(:today) { Date.new(2026, 11, 20) }

  around { |example| travel_to(today) { example.run } }

  def add(cents, date:, status: "cleared")
    create(:transaction, account: account, amount_cents: cents, date: date, status: status)
  end

  it "escenario de US-0102: 100 € con -30 € conciliado ayer y -20 € programado mañana dan 70 € y 50 €" do
    account = create(:account, opening_balance_cents: 10_000)
    create(:transaction, account: account, amount_cents: -3_000, date: Date.current - 1)
    create(:transaction, :scheduled, account: account, amount_cents: -2_000, date: Date.current + 1)

    expect(account.balance_cents).to eq(7_000)
    expect(account.projected_balance_cents).to eq(5_000)
    expect(described_class.balances_for([ account ])).to eq(account.id => [ 7_000, 5_000 ])
  end

  describe ".totals_by_currency" do
    it "suma actual y proyectado por moneda, sin convertir" do
      euros = create(:account, opening_balance_cents: 10_000)
      more_euros = create(:account, household: euros.household, opening_balance_cents: -2_500)
      dollars = create(:account, household: euros.household, currency: "USD", opening_balance_cents: 5_000)
      balances = { euros.id => [ 10_000, 9_000 ], more_euros.id => [ -2_500, -2_500 ], dollars.id => [ 5_000, 4_000 ] }

      expect(described_class.totals_by_currency([ euros, more_euros, dollars ], balances))
        .to eq("EUR" => [ 7_500, 6_500 ], "USD" => [ 5_000, 4_000 ])
    end
  end

  it "sin movimientos, ambos son el saldo inicial" do
    expect(account.balance_cents).to eq(10_000)
    expect(account.projected_balance_cents).to eq(10_000)
  end

  it "el actual suma lo conciliado hasta hoy; el proyectado suma todo" do
    add(-3_000, date: today - 1)
    add(-2_000, date: today + 1, status: "scheduled")

    expect(account.balance_cents).to eq(7_000)
    expect(account.projected_balance_cents).to eq(5_000)
  end

  it "un ingreso programado no cambia el actual y sube el proyectado" do
    add(200_000, date: Date.new(2026, 11, 28), status: "scheduled")

    expect(account.balance_cents).to eq(10_000)
    expect(account.projected_balance_cents).to eq(210_000)
  end

  it "el actual excluye lo pendiente y lo conciliado con fecha futura" do
    add(-1_000, date: today, status: "pending")
    add(-500, date: today + 1)

    expect(account.balance_cents).to eq(10_000)
    expect(account.projected_balance_cents).to eq(8_500)
  end

  it "incluye la fecha límite (fin de mes) y excluye el día siguiente" do
    add(-100, date: Date.new(2026, 10, 31))
    add(-200, date: Date.new(2026, 11, 1))

    expect(account.balance_cents(on: Date.new(2026, 10, 31))).to eq(9_900)
    expect(account.balance_cents(on: Date.new(2026, 11, 1))).to eq(9_700)
  end

  it "funciona el 29 de febrero de un año bisiesto" do
    add(-100, date: Date.new(2028, 2, 29))

    expect(account.balance_cents(on: Date.new(2028, 2, 28))).to eq(10_000)
    expect(account.balance_cents(on: Date.new(2028, 2, 29))).to eq(9_900)
    expect(account.balance_cents(on: Date.new(2028, 3, 1))).to eq(9_900)
  end

  it "editar o borrar un movimiento recalcula el saldo" do
    transaction = add(-1_250, date: today)
    expect(account.balance_cents).to eq(8_750)

    Transaction.find(transaction.id).update!(amount_input: "20", direction: "expense")
    expect(account.balance_cents).to eq(8_000)

    Transaction.find(transaction.id).destroy!
    expect(account.balance_cents).to eq(10_000)
  end

  describe ".balances_for" do
    it "devuelve actual y proyectado de varias cuentas en una consulta, incluidas las que no tienen movimientos" do
      other = create(:account, household: account.household, opening_balance_cents: 500)
      add(-3_000, date: today - 1)
      add(-2_000, date: today + 1, status: "scheduled")

      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name].in?(%w[ SCHEMA TRANSACTION ]) }
      balances = ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        described_class.balances_for([ account, other ])
      end

      expect(balances).to eq(account.id => [ 7_000, 5_000 ], other.id => [ 500, 500 ])
      expect(queries).to eq(1)
    end
  end

  describe "con movimientos" do
    it "no se puede borrar" do
      add(-100, date: today)
      reloaded = described_class.find(account.id)

      expect(reloaded.destroy).to be(false)
      expect(described_class.exists?(account.id)).to be(true)
    end

    it "no puede cambiar de moneda" do
      add(-100, date: today)
      reloaded = described_class.find(account.id)

      expect(reloaded.update(currency: "USD")).to be(false)
      expect(reloaded.errors).to be_added(:currency, :locked)
    end
  end
end
