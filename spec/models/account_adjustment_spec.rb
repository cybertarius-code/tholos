require "rails_helper"

# Ajuste de saldo (US-0108)
RSpec.describe Account, "#adjust_balance!" do
  let(:account) { create(:account, name: "Corriente BBVA", opening_balance_cents: 100_000) }
  let(:today) { Date.new(2026, 11, 20) }

  around { |example| travel_to(today) { example.run } }

  it "a la baja: crea un ajuste de -14,60 €, conciliado y sin categoría, y el saldo pasa a 985,40 €" do
    movement = account.adjust_balance!(to_cents: 98_540, on: today)

    expect(movement).to have_attributes(amount_cents: -1_460, date: today, status: "cleared", adjustment: true, category_id: nil)
    expect(account.balance_cents).to eq(98_540)
    expect(Transaction.income_and_expense).not_to include(movement)
  end

  it "al alza: crea un ajuste positivo por la diferencia" do
    movement = account.adjust_balance!(to_cents: 101_000, on: today)

    expect(movement.amount_cents).to eq(1_000)
    expect(account.balance_cents).to eq(101_000)
  end

  it "sin diferencia: no crea nada y devuelve nil" do
    expect { expect(account.adjust_balance!(to_cents: 100_000, on: today)).to be_nil }
      .not_to change(Transaction, :count)
  end

  it "en una fecha pasada: la diferencia se calcula con el saldo de ese día" do
    create(:transaction, account: account, amount_cents: -20_000, date: Date.new(2026, 11, 5))

    movement = account.adjust_balance!(to_cents: 50_000, on: Date.new(2026, 10, 31))

    expect(movement).to have_attributes(amount_cents: -50_000, date: Date.new(2026, 10, 31))
    expect(account.balance_cents(on: Date.new(2026, 10, 31))).to eq(50_000)
    expect(account.balance_cents).to eq(30_000)
  end

  it "ignora lo pendiente y lo programado, que no cuentan en el saldo" do
    create(:transaction, :scheduled, account: account, amount_cents: -5_000, date: today)

    expect(account.adjust_balance!(to_cents: 100_000, on: today)).to be_nil
  end
end
