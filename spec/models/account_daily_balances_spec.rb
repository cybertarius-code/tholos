require "rails_helper"

RSpec.describe Account, "saldo diario de 90 días" do
  let(:today) { Date.new(2026, 11, 24) }
  let(:account) { create(:account, opening_balance_cents: 100_000, opening_date: Date.new(2026, 1, 1)) }

  def movement(date, amount_cents, status: "cleared")
    create(:transaction, account: account, date: date, amount_cents: amount_cents, status: status)
  end

  it "da un punto por día, de hace 89 días a hoy, también los días sin movimientos" do
    series = account.daily_balances(on: today)

    expect(series.size).to eq(90)
    expect(series.first).to eq([ today - 89, 100_000 ])
    expect(series.last).to eq([ today, 100_000 ])
    expect(series.map(&:first)).to eq((today - 89..today).to_a)
  end

  it "parte del saldo conciliado anterior al periodo y acumula día a día" do
    movement(today - 200, -30_000)
    movement(today - 10, -2_500)
    movement(today - 10, -500)
    movement(today - 3, 10_000)

    series = account.daily_balances(on: today).to_h

    expect(series[today - 89]).to eq(70_000)
    expect(series[today - 11]).to eq(70_000)
    expect(series[today - 10]).to eq(67_000)
    expect(series[today - 4]).to eq(67_000)
    expect(series[today - 3]).to eq(77_000)
    expect(series[today]).to eq(77_000)
  end

  it "solo suma lo conciliado y nada posterior a hoy" do
    movement(today - 5, -1_000, status: "pending")
    movement(today + 1, -2_000, status: "scheduled")
    movement(today + 1, -3_000)

    expect(account.daily_balances(on: today).map(&:last).uniq).to eq([ 100_000 ])
  end

  it "cada día coincide con balance_cents(on:), y el último con el saldo actual" do
    [ -80, -40, -12, -1, 0 ].each_with_index { |offset, index| movement(today + offset, (index + 1) * -1_111) }

    travel_to(today) do
      series = account.daily_balances

      series.each { |date, cents| expect(cents).to eq(account.balance_cents(on: date)), "#{date}" }
      expect(series.last.last).to eq(account.balance_cents)
    end
  end

  it "cruza fin de mes y el 29 de febrero de un año bisiesto" do
    leap_day = Date.new(2028, 2, 29)
    movement(Date.new(2028, 2, 28), -1_000)
    movement(leap_day, -2_000)
    movement(Date.new(2028, 3, 1), -3_000)

    series = account.daily_balances(days: 4, on: Date.new(2028, 3, 1)).to_h

    expect(series.keys).to eq([ Date.new(2028, 2, 27), Date.new(2028, 2, 28), leap_day, Date.new(2028, 3, 1) ])
    expect(series.values).to eq([ 100_000, 99_000, 97_000, 94_000 ])
  end

  it "no mezcla movimientos de otras cuentas" do
    create(:transaction, account: create(:account, household: account.household), date: today, amount_cents: -99_999)

    expect(account.daily_balances(on: today).last.last).to eq(100_000)
  end

  it "hace una sola consulta" do
    account
    queries = 0
    callback = ->(*, payload) { queries += 1 unless payload[:name].in?(%w[ SCHEMA TRANSACTION ]) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { account.daily_balances(on: today) }

    expect(queries).to eq(1)
  end
end
