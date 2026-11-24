require "rails_helper"

# Cargar un extracto de Sabadell (US-0113). Ficheros sintéticos, nunca reales.
RSpec.describe Imports::Stage do
  let(:account) { create(:account, name: "Corriente Sabadell", opening_balance_cents: 100_000, opening_date: Date.new(2026, 1, 1)) }

  def upload(name)
    Rack::Test::UploadedFile.new(file_fixture(name), "text/plain")
  end

  def stage(name = "sabadell.txt")
    described_class.call(account: account, file: upload(name))
  end

  def rows_of(import)
    ImportRow.where(import: import).includes(:import).order(:line).to_a
  end

  it "carga una fila por movimiento, con la fecha de operación, en céntimos y sin tocar el saldo" do
    result = stage

    expect(result).to be_success
    rows = rows_of(result.import)
    expect(rows.map(&:line)).to eq([ 1, 2, 3, 4, 5 ])
    expect(rows[2]).to have_attributes(date: Date.new(2026, 1, 5), concept: "COMPRA TARJ. 1234XXXXXXXX5678 FARMACIA",
                                       amount_cents: -240, balance_cents: 99_350, proposal: "none", skipped: false)
    expect(rows[3].concept).to eq("ABONO BIZUM DE MARÍA FICTICIA")
    expect(result.import).to have_attributes(household_id: account.household_id, status: "staged", filename: "sabadell.txt")
    expect(Transaction.count).to eq(0)
    expect(account.balance_cents).to eq(100_000)
  end

  it "las filas hasta la fecha del saldo inicial, incluida, salen anteriores al corte y omitidas" do
    rows = rows_of(stage.import)

    expect(rows.first(2)).to all(have_attributes(proposal: "before_cutoff", skipped: true))
    expect(rows.last(3).map(&:proposal)).to all(eq("none"))
    expect(account.reload.opening_balance_cents).to eq(100_000)
  end

  it "con una línea mala no carga nada y da cada error con su línea" do
    result = nil

    expect { result = stage("sabadell_con_errores.txt") }.not_to change(Import, :count)
    expect(result).not_to be_success
    expect(result.errors.map { |error| error[:line] }).to eq([ 3, 4 ])
    expect(result.errors.first[:message]).to start_with("importe:")
    expect(ImportRow.count).to eq(0)
  end

  it "un fichero de otro formato (separador, codificación o columnas) da un aviso y no carga nada" do
    %w[ otro_banco.csv sabadell_utf8.txt ].each do |name|
      expect(stage(name).problem).to eq(:wrong_format), name
    end
    expect(described_class.call(account: account, file: nil).problem).to eq(:missing_file)
    expect(Import.count).to eq(0)
  end

  describe "huella" do
    it "dos filas iguales con distinto saldo tienen huellas distintas" do
      attributes = { account_id: 1, date: Date.new(2026, 1, 5), amount_cents: -240, concept: "CAFETERIA LUNA" }

      expect(ImportRow.fingerprint(**attributes, balance_cents: 1_000))
        .not_to eq(ImportRow.fingerprint(**attributes, balance_cents: 760))
    end

    it "corregir una fila no cambia su huella" do
      row = rows_of(stage.import).third
      ref = row.import_ref

      row.update!(concept: "Farmacia", amount_input: "-2,50")

      expect(row.reload).to have_attributes(concept: "Farmacia", amount_cents: -250, import_ref: ref)
    end
  end

  it "al reimportar un extracto confirmado, aunque se corrigieran conceptos, todo sale duplicado y omitido" do
    import = stage.import
    rows = rows_of(import)
    category = create(:category, household: account.household)
    rows.last(3).each { |row| row.update!(decision: category.id.to_s) }
    rows.third.update!(concept: "Farmacia")
    expect(Imports::Commit.call(import)).to be_success

    again = rows_of(stage.import)

    expect(again.first(2).map(&:proposal)).to all(eq("before_cutoff"))
    expect(again.last(3)).to all(have_attributes(proposal: "duplicate", skipped: true))
    expect { expect(Imports::Commit.call(again.first.import)).to be_success }.not_to change(Transaction, :count)
  end
end
