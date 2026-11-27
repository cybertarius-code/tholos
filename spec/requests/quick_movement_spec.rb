require "rails_helper"

# Modal "+ Movimiento" (US-0109): Turbo Frame "modal", cookie last_account_id
RSpec.describe "Quick movement", type: :request do
  let(:user) { create(:user, :with_household) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }
  let!(:account) { create(:account, household: household, name: "Corriente BBVA") }
  let!(:savings) { create(:account, household: household, name: "Ahorro", kind: "savings") }
  let(:modal) { { "Turbo-Frame" => "modal" } }
  let(:expense_params) do
    { transaction: { direction: "expense", amount_input: "4,20", date: Date.current.iso8601, account_id: savings.id, status: "cleared" } }
  end

  before { sign_in_as(user) }

  def selected_account_id
    response.body[/<option selected="selected" value="(\d+)">/, 1]&.to_i
  end

  it "abre el formulario en el modal con las pestañas" do
    get new_transaction_path, headers: modal

    expect(response.body).to include(%(<turbo-frame id="modal">), "<dialog")
    expect(response.body).to include(%(href="#{new_transfer_path}"))
    expect(response.body).to include(%(type="hidden" value="expense" name="transaction[direction]"))
  end

  it "guardar desde el modal cierra, refresca sin request-id y recuerda la cuenta" do
    post transactions_path, params: expense_params, headers: modal.merge("X-Turbo-Request-Id" => "abc")

    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include(%(<turbo-stream action="update" target="modal">), %(<turbo-stream action="refresh">))
    expect(response.body).not_to include("abc")
    expect(response.body).to include(%(<turbo-stream action="append" target="flash">), "data-turbo-permanent", I18n.t("transactions.create.success"))
    expect(flash[:success]).to be_nil

    get new_transaction_path, headers: modal
    expect(selected_account_id).to eq(savings.id)
  end

  it "sin el modal, sigue redirigiendo a la cuenta" do
    post transactions_path, params: expense_params

    expect(response).to redirect_to(account_path(savings))
  end

  it "ignora la última cuenta si ya está cerrada" do
    post transactions_path, params: expense_params, headers: modal
    savings.update!(status: "closed")

    get new_transaction_path, headers: modal

    expect(selected_account_id).to be_nil
  end

  it "un error deja el modal abierto con el formulario" do
    post transactions_path, params: { transaction: expense_params[:transaction].merge(amount_input: "") }, headers: modal

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("<dialog", "transaction_amount_input_error")
  end

  it "las transferencias guardan su origen como última cuenta y la usan como origen" do
    post transfers_path, headers: modal, params: {
      transfer: { from_account_id: savings.id, to_account_id: account.id, amount_input: "100", date: Date.current.iso8601 }
    }

    get new_transaction_path, headers: modal
    expect(selected_account_id).to eq(savings.id)

    get new_transfer_path, headers: modal
    from_select = response.body[%r{name="transfer\[from_account_id\]".*?</select>}m]
    expect(from_select).to include(%(<option selected="selected" value="#{savings.id}">))
  end

  it "una transferencia desde el modal también cierra y refresca" do
    post transfers_path, headers: modal, params: {
      transfer: { from_account_id: account.id, to_account_id: savings.id, amount_input: "100", date: Date.current.iso8601 }
    }

    expect(response.body).to include(%(<turbo-stream action="refresh">))
    expect(response.body).to include(I18n.t("transfers.create.success"))
  end
end
