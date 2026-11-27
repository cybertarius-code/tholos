module Transactions
  # Recibo de un movimiento (US-0107). Se sirve a través de la app, acotado al
  # hogar: las URL de Active Storage valen para cualquiera que tenga el enlace,
  # y sus rutas están desactivadas (config/application.rb).
  class ReceiptsController < ApplicationController
    before_action :set_transaction

    def show
      receipt = @transaction.receipt
      raise ActiveRecord::RecordNotFound unless receipt.attached?

      blob = receipt.blob
      # La miniatura puede cambiar de formato (HEIC → PNG): tipo y nombre, los suyos
      blob = receipt.variant(:thumb).processed.image.blob if params[:size] == "thumb" && @transaction.receipt_image?
      send_receipt(blob)
    end

    def destroy
      @transaction.receipt.purge_later if @transaction.receipt.attached?
      redirect_to edit_transaction_path(@transaction), success: t(".success"), status: :see_other
    end

    private
      def set_transaction
        @transaction = Current.household.transactions.with_attached_receipt.find(params[:transaction_id])
      end

      # Inline solo si Active Storage lo considera seguro (imágenes y PDF); el
      # resto, como descarga
      def send_receipt(blob)
        disposition = ActiveStorage.content_types_allowed_inline.include?(blob.content_type) ? :inline : :attachment
        response.headers["Cache-Control"] = "private, max-age=300"
        send_data blob.download, filename: blob.filename.to_s, type: blob.content_type, disposition: disposition
      end
  end
end
