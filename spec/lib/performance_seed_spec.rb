require "rails_helper"

RSpec.describe PerformanceSeed do
  let(:today) { Date.new(2026, 11, 24) }

  def seed(total: 400)
    described_class.new(total: total, today: today, password: "password1234")
  end

  def household
    Household.find_by!(name: "Rendimiento")
  end

  it "crea el hogar con 8 cuentas, las categorías por defecto y exactamente el total pedido" do
    expect(seed.call).to eq(400)

    expect(household.accounts.count).to eq(8)
    expect(household.categories.count).to eq(23)
    expect(Transaction.where(household_id: household.id).count).to eq(400)
    expect(User.find_by!(email_address: "perf@tholos.local").authenticate("password1234")).to be_truthy
  end

  it "reparte 3 años e incluye transferencias, ajustes, ingresos, programados y pendientes" do
    seed(total: 2_000).call
    movements = Transaction.where(household_id: household.id)

    expect(movements.minimum(:date)).to be >= today.prev_year(3)
    expect(movements.maximum(:date)).to be > today
    expect(movements.where(date: ..today.prev_year(2)).count).to be > 400
    expect(movements.where.not(transfer_id: nil).count).to eq(100)
    expect(movements.where(adjustment: true).count).to eq(10)
    expect(movements.where(status: "scheduled").where(date: ..today)).to be_empty
    expect(movements.where(status: "scheduled").count).to be_positive
    expect(movements.where(status: "pending").count).to be_positive
    expect(movements.where.not(category_id: nil).where("amount_cents > 0").count).to eq(40)
  end

  it "las transferencias tienen dos lados opuestos, misma fecha y sin categoría" do
    seed.call
    legs = Transaction.where(household_id: household.id).where.not(transfer_id: nil)

    legs.group_by(&:transfer_id).each_value do |(one, other)|
      expect(one.amount_cents).to eq(-other.amount_cents)
      expect(one.date).to eq(other.date)
      expect(one.account_id).not_to eq(other.account_id)
    end
    expect(legs.where.not(category_id: nil)).to be_empty
    expect(Transfer.where(household_id: household.id).count).to eq(legs.count / 2)
  end

  it "es idempotente: la segunda ejecución no crea nada" do
    seed.call

    expect(seed.call).to eq(0)
    expect(Household.where(name: "Rendimiento").count).to eq(1)
    expect(User.where(email_address: "perf@tholos.local").count).to eq(1)
    expect(Account.count).to eq(8)
    expect(Transaction.count).to eq(400)
  end

  it "es determinista: los mismos datos en cada ejecución" do
    snapshot = lambda do
      seed.call
      rows = Transaction.order(:date, :amount_cents, :id).pluck(:date, :amount_cents, :payee, :status)
      Transaction.delete_all
      Transfer.delete_all
      Account.delete_all
      rows
    end

    expect(snapshot.call).to eq(snapshot.call)
  end

  it "se niega en producción sin tocar la BD" do
    allow(Rails.env).to receive(:production?).and_return(true)

    expect { seed.call }.to raise_error(PerformanceSeed::ProductionError)
    expect(User.count).to eq(0)
    expect(Transaction.count).to eq(0)
  end
end
