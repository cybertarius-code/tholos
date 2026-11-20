require "rails_helper"

RSpec.describe "Accounts", type: :request do
  let(:user) { create(:user, :with_household) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }

  let(:valid_params) do
    {
      account: {
        name: "Corriente BBVA", kind: "checking", currency: "EUR",
        opening_amount: "1250.00", opening_date: "2026-01-01",
        include_in_net_worth: "1", notes: ""
      }
    }
  end

  context "sin sesión" do
    it "redirige al login" do
      get accounts_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  context "con sesión" do
    before { sign_in_as(user) }

    describe "GET /cuentas" do
      it "lista las cuentas del hogar, también las cerradas" do
        create(:account, household: household, name: "Corriente BBVA", opening_balance_cents: 125_000)
        create(:account, :closed, household: household, name: "Visa antigua")
        create(:account, name: "Cuenta ajena")

        get accounts_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Corriente BBVA", "1.250,00 €", "Visa antigua")
        expect(response.body).to include(I18n.t("accounts.statuses.closed"))
        expect(response.body).not_to include("Cuenta ajena")
      end

      it "muestra un estado vacío sin cuentas" do
        get accounts_path

        expect(response.body).to include(I18n.t("accounts.index.empty_title"))
      end
    end

    describe "GET /cuentas/nueva" do
      it "propone la moneda base del hogar" do
        household.update!(base_currency: "USD")

        get new_account_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('value="USD"')
      end
    end

    describe "POST /cuentas" do
      it "crea una cuenta de activo con su saldo inicial" do
        expect { post accounts_path, params: valid_params }.to change(household.accounts, :count).by(1)

        account = household.accounts.order(:id).last
        expect(response).to redirect_to(account_path(account))
        expect(account).to have_attributes(name: "Corriente BBVA", kind: "checking", currency: "EUR",
                                           opening_balance_cents: 125_000, opening_date: Date.new(2026, 1, 1),
                                           include_in_net_worth: true, classification: :asset)

        follow_redirect!
        expect(response.body).to include("1.250,00 €")
      end

      it "guarda la deuda inicial de una tarjeta como saldo negativo" do
        params = valid_params.deep_merge(account: { name: "Visa", kind: "credit_card", opening_amount: "300" })

        post accounts_path, params: params

        account = household.accounts.find_by!(name: "Visa")
        expect(account.opening_balance_cents).to eq(-30_000)
        expect(account.classification).to eq(:liability)
      end

      it "vuelve a mostrar el formulario con errores" do
        params = valid_params.deep_merge(account: { name: "" })

        expect { post accounts_path, params: params }.not_to change(Account, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe "PATCH /cuentas/:id" do
      it "actualiza la cuenta" do
        account = create(:account, household: household)

        patch account_path(account), params: { account: { name: "Ahorro ING", kind: "savings" } }

        expect(response).to redirect_to(account_path(account))
        expect(account.reload).to have_attributes(name: "Ahorro ING", kind: "savings")
      end

      it "vuelve a mostrar el formulario con errores" do
        account = create(:account, household: household)

        patch account_path(account), params: { account: { currency: "XX" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(account.reload.currency).to eq("EUR")
      end
    end

    describe "DELETE /cuentas/:id" do
      it "borra una cuenta sin movimientos" do
        account = create(:account, household: household)

        delete account_path(account)

        expect(response).to redirect_to(accounts_path)
        expect(Account.exists?(account.id)).to be(false)
      end

      it "no borra una cuenta con movimientos y pide cerrarla" do
        account = create(:account, household: household)
        allow_any_instance_of(Account).to receive(:movements?).and_return(true) # rubocop:disable RSpec/AnyInstance

        delete account_path(account)

        expect(response).to redirect_to(account_path(account))
        expect(flash[:error]).to eq(I18n.t("accounts.destroy.has_movements"))
        expect(Account.exists?(account.id)).to be(true)
      end
    end

    describe "cierre y reapertura" do
      it "cierra una cuenta sin saldo" do
        account = create(:account, :credit_card, household: household)

        post account_closure_path(account)

        expect(response).to redirect_to(account_path(account))
        expect(flash[:success]).to eq(I18n.t("accounts.closures.create.success"))
        expect(account.reload).to be_closed
        expect(household.accounts.open).not_to include(account)
      end

      it "cierra una cuenta con saldo, pero avisa" do
        account = create(:account, household: household, opening_balance_cents: 5_000)

        post account_closure_path(account)

        expect(flash[:warning]).to eq(I18n.t("accounts.closures.create.success_with_balance"))
        expect(account.reload).to be_closed
      end

      it "mantiene visible una cuenta cerrada y la reabre" do
        account = create(:account, :closed, household: household, name: "Visa")

        get account_path(account)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Visa", I18n.t("accounts.show.reopen"))

        delete account_closure_path(account)

        expect(response).to redirect_to(account_path(account))
        expect(account.reload).to be_open
      end
    end

    describe "aislamiento por hogar" do
      let!(:foreign) { create(:account, name: "Cuenta ajena") }

      it "devuelve 404 al ver una cuenta de otro hogar" do
        get account_path(foreign)
        expect(response).to have_http_status(:not_found)
      end

      it "devuelve 404 al editar una cuenta de otro hogar" do
        get edit_account_path(foreign)
        expect(response).to have_http_status(:not_found)

        patch account_path(foreign), params: { account: { name: "Mía" } }
        expect(response).to have_http_status(:not_found)
        expect(foreign.reload.name).to eq("Cuenta ajena")
      end

      it "devuelve 404 al borrar, cerrar o reabrir una cuenta de otro hogar" do
        delete account_path(foreign)
        expect(response).to have_http_status(:not_found)

        post account_closure_path(foreign)
        expect(response).to have_http_status(:not_found)

        delete account_closure_path(foreign)
        expect(response).to have_http_status(:not_found)

        expect(foreign.reload).to be_open
      end

      it "ignora un household_id en los parámetros" do
        post accounts_path, params: valid_params.deep_merge(account: { household_id: foreign.household_id })

        expect(household.accounts.count).to eq(1)
        expect(foreign.household.accounts.count).to eq(1)
      end
    end
  end
end
