require "rails_helper"

# Confirmar un extracto revisado (US-0113)
RSpec.describe Imports::Commit do
  let(:account) { create(:account, name: "Corriente Sabadell", opening_balance_cents: 100_000, opening_date: Date.new(2026, 1, 1)) }
  let(:household) { account.household }
  let(:restaurants) { create(:category, household: household, name: "Restaurantes") }
  let(:other_income) { create(:category, :income, household: household, name: "Otros ingresos") }
  let(:fees) { create(:category, household: household, name: "Comisiones bancarias") }
  let(:import) { Imports::Stage.call(account: account, file: Rack::Test::UploadedFile.new(file_fixture("sabadell.txt"))).import }
  # Las tres filas posteriores al corte: compra -2,40, abono +50,00 y comisión -0,63
  let(:rows) { ImportRow.where(import: import).includes(:import).order(:line).to_a.last(3) }

  around { |example| travel_to(Date.new(2026, 1, 20)) { example.run } }

  def decide(purchase: restaurants.id, credit: other_income.id, fee: fees.id)
    rows.zip([ purchase, credit, fee ]).each { |row, decision| row.update!(decision: decision.to_s) }
  end

  it "crea un movimiento por fila decidida, con su categoría y su huella, y el saldo cambia en +46,97 €" do
    decide
    result = nil

    expect { result = described_class.call(import) }.to change(Transaction, :count).by(3)
    expect(result).to have_attributes(created: 3, undecided_lines: [], failed_line: nil)
    movements = Transaction.where(account: account).order(:date).to_a
    expect(movements.map(&:amount_cents)).to eq([ -240, 5_000, -63 ])
    expect(movements.map(&:category_id)).to eq([ restaurants.id, other_income.id, fees.id ])
    expect(movements.map(&:import_ref)).to eq(rows.map(&:import_ref))
    expect(movements.first).to have_attributes(payee: "COMPRA TARJ. 1234XXXXXXXX5678 FARMACIA", status: "cleared", household_id: household.id)
    expect(account.balance_cents).to eq(100_000 + 4_697)
    expect(import.reload).to be_confirmed
  end

  it "una fila omitida no crea movimiento" do
    decide(credit: "skip")

    expect { described_class.call(import) }.to change(Transaction, :count).by(2)
    expect(Transaction.where(amount_cents: 5_000)).to be_empty
  end

  it "con filas sin decidir dice cuáles faltan y no crea nada" do
    rows.first.update!(decision: restaurants.id.to_s)
    result = nil

    expect { result = described_class.call(import) }.not_to change(Transaction, :count)
    expect(result.undecided_lines).to eq([ 4, 5 ])
    expect(import.reload).to be_staged
  end

  it "si una fila no pasa las validaciones de Transaction, no crea nada y la fila queda señalada" do
    decide
    rows.second.update!(concept: "X" * 130) # el beneficiario admite 120
    result = nil

    expect { result = described_class.call(import) }.not_to change(Transaction, :count)
    expect(result.failed_line).to eq(4)
    expect(rows.second.reload.commit_error).to include("Beneficiario")
    expect(import.reload).to be_staged

    rows.second.update!(concept: "Bizum")
    expect(described_class.call(import)).to be_success
    expect(rows.second.reload.commit_error).to be_nil
  end

  it "una importación ya confirmada no crea nada otra vez" do
    decide
    described_class.call(import)

    expect { described_class.call(import.reload) }.not_to change(Transaction, :count)
  end
end
