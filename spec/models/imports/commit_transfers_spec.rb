require "rails_helper"

# Transferencias y "ya registrado" en la importación (US-0114)
RSpec.describe Imports::Commit do
  let(:checking) { create(:account, name: "Corriente Sabadell", opening_balance_cents: 100_000, opening_date: Date.new(2026, 1, 1)) }
  let(:household) { checking.household }
  let(:savings) { create(:account, household: household, name: "Ahorro", opening_date: Date.new(2026, 1, 1)) }
  let(:pharmacy) { create(:category, household: household, name: "Farmacia") }

  around { |example| travel_to(Date.new(2026, 1, 20)) { example.run } }

  def stage(account, fixture)
    Imports::Stage.call(account: account, file: Rack::Test::UploadedFile.new(file_fixture(fixture))).import
  end

  def rows_of(import)
    ImportRow.where(import: import).includes(:import).order(:line).to_a
  end

  # Corriente: "PARA AHORRO SABADELL" -300,00 → Ahorro, y una compra
  def import_checking
    import = stage(checking, "sabadell_traspaso.txt")
    transfer_row, purchase = rows_of(import)
    transfer_row.update!(decision: "transfer:#{savings.id}")
    purchase.update!(decision: pharmacy.id.to_s)
    [ import, transfer_row ]
  end

  describe "transferencia" do
    it "crea los dos lados: la huella en la cuenta importada y el otro sin huella; ninguno cuenta como gasto ni ingreso" do
      import, row = import_checking
      result = nil

      expect { result = described_class.call(import) }.to change(Transaction, :count).by(3).and change(Transfer, :count).by(1)
      expect(result).to be_success
      transfer = Transfer.includes(:legs).last
      expect(transfer.outflow).to have_attributes(account_id: checking.id, amount_cents: -30_000, date: Date.new(2026, 1, 10),
                                                  import_ref: row.import_ref, category_id: nil)
      expect(transfer.inflow).to have_attributes(account_id: savings.id, amount_cents: 30_000, import_ref: nil, category_id: nil)
      expect(Transaction.income_and_expense.where(transfer_id: transfer.id)).to be_empty
      expect(savings.balance_cents).to eq(30_000)
    end

    it "una fila positiva es una transferencia desde la otra cuenta" do
      import = stage(savings, "sabadell_ahorro.txt")
      rows_of(import).first.update!(decision: "transfer:#{checking.id}")

      described_class.call(import)

      transfer = Transfer.includes(:legs).last
      expect(transfer.outflow.account_id).to eq(checking.id)
      expect(transfer.inflow).to have_attributes(account_id: savings.id, import_ref: be_present)
    end

    it "si Transfer no la acepta, no crea nada de la importación y la fila queda señalada" do
      import, row = import_checking
      savings.update_columns(status: "closed") # se cierra después de decidir

      result = nil
      expect { result = described_class.call(import) }.not_to change(Transaction, :count)
      expect(result.failed_line).to eq(row.line)
      expect(row.reload.commit_error).to be_present
      expect(import.reload).to be_staged
    end
  end

  describe "ya registrado" do
    it "no crea nada y da la huella al lado de entrada; al reimportar, la fila sale duplicada" do
      described_class.call(import_checking.first)
      inflow = Transfer.includes(:legs).last.inflow

      import = stage(savings, "sabadell_ahorro.txt")
      row = rows_of(import).first
      row.update!(decision: "recorded:#{inflow.id}")
      result = nil

      expect { result = described_class.call(import) }.not_to change(Transaction, :count)
      expect(result).to have_attributes(created: 0, linked: 1)
      expect(inflow.reload.import_ref).to eq(row.import_ref)
      expect(rows_of(stage(savings, "sabadell_ahorro.txt")).map(&:proposal)).to eq([ "duplicate" ])
    end

    it "dos filas que apuntan al mismo movimiento: falla y no se crea ni se enlaza nada" do
      existing = create(:transaction, account: checking, amount_cents: -30_000, date: Date.new(2026, 1, 10))
      import = stage(checking, "sabadell_traspaso.txt")
      first, second = rows_of(import)
      first.update!(decision: "recorded:#{existing.id}")
      second.update_columns(amount_cents: -30_000, matched_transaction_id: existing.id) # saltando la validación
      result = nil

      expect { result = described_class.call(import) }.not_to change(Transaction, :count)
      expect(result.failed_line).to eq(second.line)
      expect(second.reload.commit_error).to include("ya está enlazado")
      expect(existing.reload.import_ref).to be_nil
    end
  end
end
