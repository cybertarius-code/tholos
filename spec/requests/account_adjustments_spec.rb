require "rails_helper"

# Ajustar el saldo de una cuenta (US-0108)
RSpec.describe "Account adjustments", type: :request do
  let(:user) { create(:user, :with_household) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }
  let!(:account) { create(:account, household: household, name: "Corriente BBVA", opening_balance_cents: 100_000) }

  def adjust(target = account, amount: "985,40", date: Date.current.iso8601)
    post account_adjustment_path(target), params: { adjustment: { amount_input: amount, date: date } }
  end

  it "sin sesión redirige al login" do
    get new_account_adjustment_path(account)

    expect(response).to redirect_to(new_session_path)
  end

  context "con sesión" do
    before { sign_in_as(user) }

    it "GET nuevo muestra el formulario con el saldo actual" do
      get new_account_adjustment_path(account)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Saldo real", "1.000,00 €")
    end

    it "crea el ajuste por la diferencia y vuelve a la cuenta" do
      expect { adjust }.to change(Transaction, :count).by(1)

      expect(response).to redirect_to(account_path(account))
      expect(flash[:success]).to eq(I18n.t("accounts.adjustments.create.success"))
      expect(Transaction.last).to have_attributes(amount_cents: -1_460, adjustment: true, category_id: nil, status: "cleared")
    end

    it "sin diferencia no crea nada y avisa de que el saldo ya coincide" do
      expect { adjust(amount: "1.000,00") }.not_to change(Transaction, :count)

      expect(response).to redirect_to(account_path(account))
      expect(flash[:info]).to eq(I18n.t("accounts.adjustments.create.unchanged"))
    end

    it "en una tarjeta se escribe la deuda en positivo" do
      visa = create(:account, :credit_card, household: household, opening_balance_cents: -25_000)

      adjust(visa, amount: "300")

      expect(Transaction.last.amount_cents).to eq(-5_000)
      expect(visa.balance_cents).to eq(-30_000)
    end

    it "sin importe vuelve al formulario con el error junto al campo" do
      expect { adjust(amount: "") }.not_to change(Transaction, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("adjustment_amount_input_error")
    end

    it "no admite cuentas cerradas ni de otro hogar" do
      closed = create(:account, :closed, household: household)
      other = create(:account)

      get new_account_adjustment_path(closed)
      expect(response).to have_http_status(:not_found)

      adjust(other)
      expect(response).to have_http_status(:not_found)
      expect(Transaction.count).to eq(0)
    end
  end
end
