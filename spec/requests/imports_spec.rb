require "rails_helper"

# Importar un extracto de Sabadell (US-0113)
RSpec.describe "Imports", type: :request do
  let(:user) { create(:user, :with_household) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }
  let!(:account) do
    create(:account, household: household, name: "Corriente Sabadell", opening_balance_cents: 100_000, opening_date: Date.new(2026, 1, 1))
  end
  let(:restaurants) { create(:category, household: household, name: "Restaurantes") }

  def upload(name = "sabadell.txt", to: account)
    post account_imports_path(to), params: { file: fixture_file_upload(name, "text/plain") }
  end

  def staged_import
    upload
    Import.last
  end

  def rows_of(import)
    ImportRow.where(import: import).order(:line).to_a
  end

  it "sin sesión redirige al login" do
    get new_account_import_path(account)

    expect(response).to redirect_to(new_session_path)
  end

  context "con sesión" do
    before { sign_in_as(user) }

    it "carga el extracto y muestra sus filas sin tocar el saldo" do
      upload
      import = Import.last

      expect(response).to redirect_to(account_import_path(account, import))
      follow_redirect!
      expect(response.body).to include("COMPRA TARJ. 1234XXXXXXXX5678 FARMACIA", %(value="-2,40"), "993,50 €", "Anterior al corte")
      expect(Transaction.count).to eq(0)
      expect(account.balance_cents).to eq(100_000)
    end

    it "con errores no carga nada y lista cada error con su línea" do
      expect { upload("sabadell_con_errores.txt") }.not_to change(Import, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Línea 3: importe:", "Línea 4: fecha:")
    end

    it "un fichero de otro formato da un aviso claro" do
      upload("otro_banco.csv")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("imports.new.problems.wrong_format"))
    end

    it "corrige una fila en su Turbo Frame y no deja cambiar las anteriores al corte" do
      import = staged_import
      before_cutoff, _, purchase = rows_of(import)

      patch import_row_path(purchase), params: { import_row: { concept: "Farmacia", amount_input: "-2,40", date: "2026-01-05", decision: restaurants.id } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<turbo-frame id="import_row_#{purchase.id}">), %(value="Farmacia"))
      expect(purchase.reload).to have_attributes(concept: "Farmacia", category_id: restaurants.id)

      patch import_row_path(before_cutoff), params: { import_row: { decision: restaurants.id } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(before_cutoff.reload).to be_skipped
    end

    it "confirmar con filas sin decidir dice cuáles faltan" do
      import = staged_import

      post import_commit_path(import)

      expect(response).to redirect_to(account_import_path(account, import))
      expect(flash[:error]).to include("3, 4 y 5")
      expect(Transaction.count).to eq(0)
    end

    it "confirmar crea los movimientos y vuelve a la cuenta" do
      import = staged_import
      rows_of(import).last(3).each { |row| row.update_columns(category_id: restaurants.id) }

      post import_commit_path(import)

      expect(response).to redirect_to(account_path(account))
      expect(Transaction.count).to eq(3)
      get account_import_path(account, import)
      expect(response.body).to include(I18n.t("imports.show.committed"))
      expect(response.body).not_to include(I18n.t("imports.show.commit"))
    end

    it "no deja importar en una cuenta de otro hogar, ni ver, corregir o confirmar sus importaciones" do
      other_account = create(:account, opening_date: Date.new(2026, 1, 1))
      other_import = Imports::Stage.call(account: other_account, file: fixture_file_upload("sabadell.txt")).import
      other_row = rows_of(other_import).last

      get new_account_import_path(other_account)
      expect(response).to have_http_status(:not_found)
      upload(to: other_account)
      expect(response).to have_http_status(:not_found)
      get account_import_path(other_account, other_import)
      expect(response).to have_http_status(:not_found)
      patch import_row_path(other_row), params: { import_row: { concept: "x" } }
      expect(response).to have_http_status(:not_found)
      post import_commit_path(other_import)
      expect(response).to have_http_status(:not_found)
      expect(Import.count).to eq(1)
    end

    it "la ficha de la cuenta enlaza a importar un extracto" do
      get account_path(account)

      expect(response.body).to include(new_account_import_path(account), I18n.t("accounts.show.import_statement"))
    end
  end

  describe "transferencias y ya registrado (US-0114)" do
    before { sign_in_as(user) }

    around { |example| travel_to(Date.new(2026, 1, 20)) { example.run } }

    def options_for(row)
      Nokogiri::HTML(response.body).css("turbo-frame#import_row_#{row.id} select option").to_h { |option| [ option["value"], option.text ] }
    end

    it "la transferencia solo ofrece cuentas activas del hogar, de la misma moneda y distintas de la importada" do
      savings = create(:account, household: household, name: "Ahorro")
      create(:account, household: household, name: "Cuenta en dólares", currency: "USD")
      create(:account, :closed, household: household, name: "Cerrada")
      create(:account, name: "De otro hogar")
      upload("sabadell_traspaso.txt")
      import = Import.last

      get account_import_path(account, import)

      options = options_for(rows_of(import).first)
      transfer_options = options.select { |value, _| value.start_with?("transfer:") }
      expect(transfer_options).to eq("transfer:#{savings.id}" => "Ahorro")
      expect(response.body).to include("Transferencia a")
    end

    it "ya registrado solo ofrece movimientos de esta cuenta con el mismo importe, sin huella y a ± 7 días" do
      match = create(:transaction, account: account, amount_cents: -30_000, date: Date.new(2026, 1, 15), payee: "Traspaso a mano")
      create(:transaction, account: account, amount_cents: -30_000, date: Date.new(2026, 1, 18))
      create(:transaction, account: account, amount_cents: -29_999, date: Date.new(2026, 1, 10))
      create(:transaction, account: account, amount_cents: -30_000, date: Date.new(2026, 1, 10), import_ref: "ya-importado")
      create(:transaction, account: create(:account, household: household), amount_cents: -30_000, date: Date.new(2026, 1, 10))
      upload("sabadell_traspaso.txt")
      import = Import.last
      row = rows_of(import).first

      get account_import_path(account, import)

      recorded = options_for(row).select { |value, _| value.start_with?("recorded:") }
      expect(recorded.keys).to eq([ "recorded:#{match.id}" ])
      expect(recorded.values.first).to include("Traspaso a mano")

      patch import_row_path(row), params: { import_row: { decision: "recorded:#{match.id}" } }
      expect(response).to have_http_status(:ok)
      expect(row.reload.matched_transaction_id).to eq(match.id)
    end

    it "rechaza una cuenta de otro hogar al guardar la fila" do
      upload("sabadell_traspaso.txt")
      row = rows_of(Import.last).first

      patch import_row_path(row), params: { import_row: { decision: "transfer:#{create(:account).id}" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(row.reload.counter_account_id).to be_nil
    end
  end
end
