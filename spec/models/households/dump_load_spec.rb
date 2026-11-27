require "rails_helper"

# Copiar un hogar a otro (KB-0006)
RSpec.describe "Households::Dump y Households::Load" do
  let(:source) { create(:household, name: "Hogar de prueba") }
  let(:target) { create(:household, name: "Hogar definitivo").tap(&:seed_default_categories!) }
  let(:checking) { create(:account, household: source, name: "Corriente Sabadell", opening_balance_cents: 100_000, opening_date: Date.new(2026, 1, 1)) }
  let(:savings) { create(:account, household: source, name: "Ahorro", kind: "savings", opening_balance_cents: 50_000) }
  let(:restaurants) { create(:category, household: source, name: "Restaurantes") }
  let(:coffee) { create(:category, :child, household: source, parent: restaurants, name: "Cafeterías") }
  let(:old_income) { create(:category, :income, household: source, name: "Ingreso antiguo") }

  def statement
    Rack::Test::UploadedFile.new(file_fixture("sabadell.txt"))
  end

  def rows_of(import)
    ImportRow.where(import: import).includes(:import).order(:line).to_a
  end

  # Por JSON, como en la tarea: fechas y horas pasan a texto
  def copy
    Households::Load.call(target, JSON.parse(JSON.generate(Households::Dump.call(source))))
  end

  def target_account(name)
    Account.find_by!(household: target, name: name)
  end

  before do
    create(:transaction, account: checking, category: coffee, amount_cents: -350, date: Date.new(2026, 1, 3), payee: "Café Sol")
    create(:transaction, account: checking, category: old_income, amount_cents: 2_000, date: Date.new(2026, 1, 4))
    create(:transaction, :scheduled, account: savings, amount_cents: -1_000, date: Date.new(2026, 2, 1))
    checking.adjust_balance!(to_cents: 100_000, on: Date.new(2026, 1, 2)) # sin diferencia: no crea nada
    savings.adjust_balance!(to_cents: 49_000, on: Date.new(2026, 1, 2))
    Transfer.record!(household: source, from: checking, to: savings, amount_cents: 10_000, date: Date.new(2026, 1, 6))

    # Extracto importado: compra con el concepto corregido, abono como transferencia desde Ahorro y comisión
    import = Imports::Stage.call(account: checking, file: statement).import
    purchase, credit, fee = rows_of(import).last(3)
    purchase.update!(concept: "Farmacia", decision: restaurants.id.to_s)
    credit.update!(decision: "transfer:#{savings.id}")
    fee.update!(decision: restaurants.id.to_s)
    expect(Imports::Commit.call(import)).to be_success

    old_income.update!(archived_at: Time.current)
    savings.close!
  end

  it "copia cuentas, categorías y movimientos con los mismos saldos, en la misma base de datos" do
    result = copy

    expect(result).to have_attributes(accounts: 2, fingerprints_lost: 0)
    expect(result.transactions).to eq(Transaction.where(household: source).count)
    [ checking, savings ].each do |account|
      copied = target_account(account.name)
      expect([ copied.balance_cents, copied.projected_balance_cents ]).to eq([ account.balance_cents, account.projected_balance_cents ])
    end
    expect(target_account("Ahorro")).to be_closed
    expect(Transaction.where(household: target, adjustment: true).count).to eq(1)
    expect(Transfer.where(household: target).count).to eq(2)
    expect(Transaction.find_by!(household: target, payee: "Farmacia").amount_cents).to eq(-240)
  end

  it "reutiliza las categorías que ya tiene el destino y crea las que faltan, archivadas si lo estaban" do
    restaurants_before = Category.find_by!(household: target, name: "Restaurantes")

    copy

    coffee_copy = Category.find_by!(household: target, name: "Cafeterías")
    expect(coffee_copy.parent_id).to eq(restaurants_before.id)
    expect(Transaction.find_by!(household: target, payee: "Café Sol").category_id).to eq(coffee_copy.id)
    expect(Category.find_by!(household: target, name: "Ingreso antiguo")).to be_archived
    expect(Category.where(household: target, name: "Restaurantes").count).to eq(1)
  end

  it "recalcula las huellas: el mismo extracto subido en el hogar nuevo sale entero duplicado" do
    copy

    again = Imports::Stage.call(account: target_account("Corriente Sabadell"), file: statement).import

    expect(rows_of(again).last(3)).to all(have_attributes(proposal: "duplicate", skipped: true))
  end

  it "una huella sin datos originales se pierde y se cuenta" do
    create(:transaction, account: checking, amount_cents: -100, date: Date.new(2026, 1, 9), import_ref: "huella-sin-fila")

    result = copy

    expect(result.fingerprints_lost).to eq(1)
    expect(Transaction.where(household: target, import_ref: nil, amount_cents: -100)).to exist
  end

  it "no carga en un hogar con cuentas, ni un fichero que no es un volcado" do
    create(:account, household: target)
    dump = Households::Dump.call(source)

    expect { Households::Load.call(target, dump) }.to raise_error(ArgumentError, /ya tiene cuentas/)
    expect { Households::Load.call(create(:household), { "format" => "otro" }) }.to raise_error(ArgumentError, /No es un volcado/)
  end
end
