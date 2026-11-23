require "rails_helper"

RSpec.describe "Transfers", type: :request do
  let(:user) { create(:user, :with_household) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }
  let!(:checking) { create(:account, household: household, name: "Corriente BBVA", opening_balance_cents: 100_000) }
  let!(:savings) { create(:account, household: household, name: "Ahorro", kind: "savings") }

  def transfer_params(from: checking, to: savings, amount: "300")
    { transfer: { from_account_id: from.id, to_account_id: to.id, amount_input: amount,
                  date: Date.current.iso8601, notes: "" } }
  end

  def record_transfer
    Transfer.record!(household: household, from: checking, to: savings, amount_cents: 30_000, date: Date.current)
  end

  it "sin sesión redirige al login" do
    get new_transfer_path

    expect(response).to redirect_to(new_session_path)
  end

  context "con sesión" do
    before { sign_in_as(user) }

    it "GET /transferencias/nueva desde una cuenta la pone como origen, y desde una tarjeta como destino" do
      visa = create(:account, :credit_card, household: household, name: "Visa")

      get new_transfer_path(account_id: checking.id)
      expect(response.body).to match(/name="transfer\[from_account_id\]".*?<option selected="selected" value="#{checking.id}">/m)

      get new_transfer_path(account_id: visa.id)
      expect(response.body).to match(/name="transfer\[to_account_id\]".*?<option selected="selected" value="#{visa.id}">/m)
    end

    it "POST registra los dos lados y vuelve a la cuenta de origen" do
      expect { post transfers_path, params: transfer_params }
        .to change(Transfer, :count).by(1).and change(Transaction, :count).by(2)

      expect(response).to redirect_to(account_path(checking))
      expect(Transaction.order(:amount_cents).pluck(:account_id, :amount_cents))
        .to eq([ [ checking.id, -30_000 ], [ savings.id, 30_000 ] ])
    end

    it "POST con la misma cuenta, otra moneda o una cuenta cerrada muestra el error y no guarda nada" do
      dollars = create(:account, household: household, currency: "USD")
      closed = create(:account, :closed, household: household)

      [ checking, dollars, closed ].each do |to|
        expect { post transfers_path, params: transfer_params(to: to) }.not_to change(Transaction, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('role="alert"')
      end
    end

    it "PATCH actualiza los dos lados" do
      transfer = record_transfer

      patch transfer_path(transfer), params: transfer_params(amount: "45,50")

      expect(response).to redirect_to(account_path(checking))
      expect(Transaction.where(transfer_id: transfer.id).pluck(:amount_cents)).to contain_exactly(-4_550, 4_550)
    end

    it "editar un lado desde movimientos lleva a la transferencia" do
      transfer = record_transfer

      get edit_transaction_path(transfer.inflow)
      expect(response).to redirect_to(edit_transfer_path(transfer))

      patch transaction_path(transfer.inflow), params: { transaction: { amount_input: "1" } }
      expect(response).to redirect_to(edit_transfer_path(transfer))
      expect(transfer.inflow.reload.amount_cents).to eq(30_000)
    end

    it "DELETE de la transferencia o de uno de sus lados borra los dos" do
      transfer = record_transfer
      expect { delete transfer_path(transfer) }.to change(Transaction, :count).by(-2)
      expect(response).to redirect_to(account_path(checking))

      transfer = record_transfer
      expect { delete transaction_path(transfer.outflow) }.to change(Transaction, :count).by(-2)
      expect(Transfer.exists?(transfer.id)).to be(false)
    end

    it "la ficha de la cuenta muestra 'Transferencia a/desde' con un enlace a la otra cuenta" do
      record_transfer

      get account_path(checking)
      expect(response.body).to include(I18n.t("accounts.show.transfer_to"))
        .and include(%(href="#{account_path(savings)}"))

      get account_path(savings)
      expect(response.body).to include(I18n.t("accounts.show.transfer_from"))
        .and include(%(href="#{account_path(checking)}"))
    end

    it "la ficha hace las mismas consultas con 1 y con 5 transferencias (sin N+1)" do
      record_transfer
      count_queries = lambda do
        queries = 0
        callback = ->(*, payload) { queries += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) }
        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get account_path(checking) }
        queries
      end

      one = count_queries.call
      4.times { record_transfer }

      expect(count_queries.call).to eq(one)
    end

    it "una transferencia de otro hogar da 404" do
      other = create(:account)
      foreign = Transfer.record!(household: other.household, from: other, to: create(:account, household: other.household),
                                 amount_cents: 100, date: Date.current)

      get edit_transfer_path(foreign)
      expect(response).to have_http_status(:not_found)
      delete transfer_path(foreign)
      expect(response).to have_http_status(:not_found)
    end
  end
end
