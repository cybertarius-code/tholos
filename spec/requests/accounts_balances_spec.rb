require "rails_helper"

RSpec.describe "Accounts list balances", type: :request do
  let(:user) { create(:user, :with_household) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }

  before { sign_in_as(user) }

  def queries_for_index
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name].in?(%w[ SCHEMA TRANSACTION ]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get accounts_path }
    queries
  end

  it "muestra el saldo actual con movimientos y hace las mismas consultas con 1 y con 10 cuentas" do
    first = create(:account, household: household, name: "Corriente", opening_balance_cents: 10_000)
    create(:transaction, account: first, amount_cents: -2_500, date: Date.current)
    get accounts_path # calentamiento
    expect(response.body).to include("75,00 €")
    with_one = queries_for_index

    9.times do |i|
      account = create(:account, household: household, name: "Cuenta #{i}")
      create(:transaction, account: account, amount_cents: -100, date: Date.current)
    end

    expect(queries_for_index).to eq(with_one)
  end
end
