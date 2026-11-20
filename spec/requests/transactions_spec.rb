require "rails_helper"

RSpec.describe "Transactions", type: :request do
  let(:user) { create(:user, :with_household) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }
  let!(:account) { create(:account, household: household, name: "Corriente BBVA", opening_balance_cents: 100_000) }
  let!(:food) { create(:category, household: household, name: "Alimentación") }
  let!(:salary) { create(:category, :income, household: household, name: "Nómina") }

  let(:expense_params) do
    { transaction: { direction: "expense", amount_input: "12,50", date: Date.current.iso8601, account_id: account.id,
                     category_id: food.id, status: "cleared", payee: "Mercadona", notes: "" } }
  end

  context "sin sesión" do
    it "redirige al login" do
      get new_transaction_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  context "con sesión" do
    before { sign_in_as(user) }

    describe "GET /movimientos/nuevo" do
      it "ofrece solo cuentas abiertas y agrupa las categorías por padre y tipo" do
        create(:account, :closed, household: household, name: "Visa antigua")
        create(:category, :child, household: household, parent: food, name: "Supermercado")

        get new_transaction_path(account_id: account.id)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Corriente BBVA").and(match(/<option selected="selected" value="#{account.id}">/))
        expect(response.body).not_to include("Visa antigua")
        expect(response.body).to include(%(<optgroup label="Alimentación" data-kind="expense">))
        expect(response.body).to include("Supermercado", %(data-kind="income"))
      end
    end

    describe "POST /movimientos" do
      it "registra un gasto en negativo y el saldo baja" do
        expect { post transactions_path, params: expense_params }.to change(household.transactions, :count).by(1)

        transaction = household.transactions.order(:id).last
        expect(response).to redirect_to(account_path(account))
        expect(transaction).to have_attributes(amount_cents: -1_250, currency: "EUR", status: "cleared", payee: "Mercadona")
        expect(Account.find(account.id).balance_cents).to eq(98_750)
      end

      it "registra un ingreso programado: sube el proyectado, no el actual" do
        post transactions_path, params: expense_params.deep_merge(
          transaction: { direction: "income", amount_input: "2.000", category_id: salary.id, status: "scheduled",
                         date: (Date.current + 8).iso8601 }
        )

        reloaded = Account.find(account.id)
        expect(reloaded.balance_cents).to eq(100_000)
        expect(reloaded.projected_balance_cents).to eq(300_000)
      end

      it "no guarda un importe cero" do
        expect { post transactions_path, params: expense_params.deep_merge(transaction: { amount_input: "0" }) }
          .not_to change(Transaction, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include(I18n.t("activerecord.errors.models.transaction.attributes.amount.cannot_be_zero"))
      end

      it "no guarda en una cuenta cerrada" do
        account.close!

        expect { post transactions_path, params: expense_params }.not_to change(Transaction, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "no guarda en una cuenta de otro hogar" do
        foreign = create(:account)

        expect { post transactions_path, params: expense_params.deep_merge(transaction: { account_id: foreign.id }) }
          .not_to change(Transaction, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe "editar y borrar" do
      let!(:transaction) { create(:transaction, account: account, category: food, amount_cents: -1_250, date: Date.current) }

      it "muestra el importe en positivo con la pestaña de gasto marcada" do
        get edit_transaction_path(transaction)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('value="12,50"')
        expect(response.body).to match(/value="expense"[^>]*checked="checked"|checked="checked"[^>]*value="expense"/)
      end

      it "editar el importe recalcula el saldo" do
        patch transaction_path(transaction), params: { transaction: { direction: "expense", amount_input: "20" } }

        expect(response).to redirect_to(account_path(account))
        expect(Account.find(account.id).balance_cents).to eq(98_000)
      end

      it "borrar recalcula el saldo" do
        delete transaction_path(transaction)

        expect(response).to redirect_to(account_path(account))
        expect(Account.find(account.id).balance_cents).to eq(100_000)
      end

      it "la cuenta muestra sus movimientos sin N+1" do
        create_list(:transaction, 3, account: account, category: food)

        get account_path(account)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(edit_transaction_path(transaction))
      end
    end

    describe "aislamiento por hogar" do
      let!(:foreign) { create(:transaction) }

      it "devuelve 404 al editar, actualizar o borrar un movimiento de otro hogar" do
        get edit_transaction_path(foreign)
        expect(response).to have_http_status(:not_found)

        patch transaction_path(foreign), params: { transaction: { amount_input: "1" } }
        expect(response).to have_http_status(:not_found)

        delete transaction_path(foreign)
        expect(response).to have_http_status(:not_found)

        expect(Transaction.exists?(foreign.id)).to be(true)
      end
    end
  end
end
