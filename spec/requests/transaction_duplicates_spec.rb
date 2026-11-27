require "rails_helper"

# Duplicar un movimiento (US-0111)
RSpec.describe "Transaction duplicates", type: :request do
  let(:user) { create(:user, :with_household) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }
  let(:account) { create(:account, household: household, name: "Corriente BBVA") }
  let(:fuel) { create(:category, household: household, name: "Gasolina") }
  let(:original) do
    create(:transaction, account: account, category: fuel, amount_cents: -6_000, date: Date.new(2026, 11, 2),
                         payee: "Gasolinera Repsol", notes: "Depósito lleno", status: "pending")
  end

  def form
    Nokogiri::HTML(response.body)
  end

  def value_of(name)
    field = form.at_css("[name='#{name}']:not([type=hidden]), select[name='#{name}']") || form.at_css("[name='#{name}']")
    field.name == "select" ? field.at_css("option[selected]")&.[]("value") : field["value"]
  end

  it "sin sesión redirige al login" do
    get new_transaction_duplicate_path(original)

    expect(response).to redirect_to(new_session_path)
  end

  context "con sesión" do
    before { sign_in_as(user) }

    it "abre el formulario con cuenta, categoría, importe, beneficiario y notas, la fecha de hoy y sin guardar nada" do
      original
      expect { get new_transaction_duplicate_path(original) }.not_to change(Transaction, :count)

      expect(response).to have_http_status(:ok)
      expect(form.at_css("main form[action='#{transactions_path}'][method=post]")).to be_present
      expect(value_of("transaction[account_id]")).to eq(account.id.to_s)
      expect(value_of("transaction[category_id]")).to eq(fuel.id.to_s)
      expect(value_of("transaction[amount_input]")).to eq("60,00")
      expect(value_of("transaction[payee]")).to eq("Gasolinera Repsol")
      expect(form.at_css("textarea[name='transaction[notes]']").text.strip).to eq("Depósito lleno")
      expect(value_of("transaction[date]")).to eq(Date.current.iso8601)
      expect(value_of("transaction[status]")).to eq("cleared")
      expect(form.at_css("input[name='transaction[direction]'][value=expense][checked]")).to be_present
    end

    it "en el modal, la pestaña activa es la del signo" do
      income = create(:transaction, :income, account: account, amount_cents: 2_000)

      get new_transaction_duplicate_path(income), headers: { "Turbo-Frame" => "modal" }

      expect(form.at_css("nav a[aria-current=page]").text).to eq(I18n.t("quick_movement.tabs.income"))
      expect(value_of("transaction[direction]")).to eq("income")
    end

    it "una cuenta cerrada o una categoría archivada quedan sin elegir" do
      original
      account.update_columns(status: "closed")
      fuel.archive!

      get new_transaction_duplicate_path(original)

      expect(value_of("transaction[account_id]")).to be_blank
      expect(value_of("transaction[category_id]")).to be_blank
    end

    it "un lado de una transferencia abre la transferencia con las dos cuentas y el importe" do
      savings = create(:account, household: household, name: "Ahorro")
      transfer = Transfer.record!(household: household, from: account, to: savings, amount_cents: 30_000,
                                  date: Date.new(2026, 11, 2), notes: "Ahorro mensual")

      get new_transaction_duplicate_path(transfer.inflow), headers: { "Turbo-Frame" => "modal" }

      expect(form.at_css("form[action='#{transfers_path}'][method=post]")).to be_present
      expect(value_of("transfer[from_account_id]")).to eq(account.id.to_s)
      expect(value_of("transfer[to_account_id]")).to eq(savings.id.to_s)
      expect(value_of("transfer[amount_input]")).to eq("300,00")
      expect(form.at_css("nav a[aria-current=page]").text).to eq(I18n.t("quick_movement.tabs.transfer"))
    end

    it "un ajuste no se duplica, y el movimiento de otro hogar tampoco" do
      adjustment = create(:transaction, account: account, adjustment: true)

      get new_transaction_duplicate_path(adjustment)
      expect(response).to have_http_status(:not_found)
      get new_transaction_duplicate_path(create(:transaction))
      expect(response).to have_http_status(:not_found)
    end

    it "la edición y la lista ofrecen Duplicar, salvo en los ajustes" do
      adjustment = create(:transaction, account: account, adjustment: true, date: original.date)

      get edit_transaction_path(original)
      expect(response.body).to include(new_transaction_duplicate_path(original))

      get transactions_path(month: "2026-11")
      expect(response.body).to include(new_transaction_duplicate_path(original))
      expect(response.body).not_to include(new_transaction_duplicate_path(adjustment))
    end
  end
end
