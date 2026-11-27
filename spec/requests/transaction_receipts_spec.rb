require "rails_helper"

# Recibos privados (US-0107)
RSpec.describe "Transaction receipts", type: :request do
  let(:user) { create(:user, :with_household) }
  let(:household) { Household.joins(:memberships).find_by!(memberships: { user_id: user.id }) }
  let(:account) { create(:account, household: household) }
  let(:food) { create(:category, household: household, name: "Alimentación") }
  let(:transaction) { create(:transaction, account: account, category: food, payee: "Mercadona") }

  def upload(name, to: transaction)
    patch transaction_path(to), params: { transaction: { receipt: fixture_file_upload(name) } }
  end

  def with_receipt(record, name)
    record.update!(receipt: Rack::Test::UploadedFile.new(file_fixture(name)))
    record
  end

  it "sin sesión, el recibo redirige al login" do
    get transaction_receipt_path(with_receipt(transaction, "recibo.jpg"))

    expect(response).to redirect_to(new_session_path)
  end

  context "con sesión" do
    before { sign_in_as(user) }

    it "adjunta una foto: la edición muestra la miniatura y el recibo se sirve por la app" do
      upload("recibo.jpg")
      expect(response).to redirect_to(account_path(account))

      get edit_transaction_path(transaction)
      expect(response.body).to include(transaction_receipt_path(transaction, size: "thumb"), I18n.t("transactions.edit.remove_receipt"))
      expect(response.body).not_to include("/rails/active_storage")

      get transaction_receipt_path(transaction)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/jpeg")
      expect(response.headers["Content-Disposition"]).to start_with("inline")
      expect(response.headers["Cache-Control"]).to include("private")

      get transaction_receipt_path(transaction, size: "thumb")
      expect(response).to have_http_status(:ok)
      expect(response.body.bytesize).to be < file_fixture("recibo.jpg").size
    end

    it "un PDF se enlaza como \"Ver factura\" y la lista marca el movimiento" do
      upload("factura.pdf")

      get edit_transaction_path(transaction)
      expect(response.body).to include(I18n.t("transactions.receipt.view_invoice"))
      get transaction_receipt_path(transaction)
      expect(response.media_type).to eq("application/pdf")

      get transactions_path(month: transaction.date.strftime("%Y-%m"))
      expect(response.body).to include(%(aria-label="#{I18n.t('transactions.receipt.view')}"))
    end

    it "un .zip da un error y no se guarda" do
      upload("recibos.zip")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.transaction.attributes.receipt.content_type"))
      expect(ActiveStorage::Attachment.count).to eq(0)
    end

    it "quita el recibo" do
      with_receipt(transaction, "recibo.jpg")

      perform_enqueued_jobs { delete transaction_receipt_path(transaction) }

      expect(response).to redirect_to(edit_transaction_path(transaction))
      expect(ActiveStorage::Attachment.count).to eq(0)
      expect(ActiveStorage::Blob.count).to eq(0)
    end

    it "cambiar el recibo borra el anterior, y borrar el movimiento borra el suyo" do
      with_receipt(transaction, "recibo.jpg")

      perform_enqueued_jobs { upload("factura.pdf") }
      expect(ActiveStorage::Blob.pluck(:content_type)).to eq([ "application/pdf" ])

      perform_enqueued_jobs { delete transaction_path(transaction) }
      expect(response).to redirect_to(account_path(account))
      expect(ActiveStorage::Blob.count).to eq(0)
    end

    it "el recibo de otro hogar da 404, y un movimiento sin recibo también" do
      other = with_receipt(create(:transaction), "recibo.jpg")

      get transaction_receipt_path(other)
      expect(response).to have_http_status(:not_found)
      get transaction_receipt_path(other, size: "thumb")
      expect(response).to have_http_status(:not_found)
      delete transaction_receipt_path(other)
      expect(response).to have_http_status(:not_found)
      expect(other.reload.receipt).to be_attached

      get transaction_receipt_path(transaction)
      expect(response).to have_http_status(:not_found)
    end

    it "las rutas públicas de Active Storage no existen" do
      blob = with_receipt(transaction, "recibo.jpg").receipt.blob

      get "/rails/active_storage/blobs/redirect/#{blob.signed_id}/recibo.jpg"
      expect(response).to have_http_status(:not_found)
    end
  end
end
