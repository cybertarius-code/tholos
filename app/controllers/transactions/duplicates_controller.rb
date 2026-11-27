module Transactions
  # Duplicar un movimiento (US-0111): abre el formulario de alta precargado, sin
  # guardar nada. Copia cuenta, categoría, importe, beneficiario y notas con la
  # fecha de hoy; no copia el recibo ni el estado. Un lado de una transferencia
  # abre el formulario de transferencia; un ajuste no se duplica.
  class DuplicatesController < ApplicationController
    layout :modal_layout

    def new
      original = Current.household.transactions.find(params[:transaction_id])
      raise ActiveRecord::RecordNotFound if original.adjustment?

      if original.transfer?
        @transfer = duplicate_transfer(Current.household.transfers.includes(:legs).find(original.transfer_id))
        render "transfers/new"
      else
        @transaction = duplicate_transaction(original)
        render "transactions/new"
      end
    end

    private
      # Una cuenta cerrada o una categoría archivada no admiten movimientos
      # nuevos: se dejan sin elegir
      def duplicate_transaction(original)
        Current.household.transactions.new(
          account_id: open_account_id(original.account_id),
          category_id: Current.household.categories.active.find_by(id: original.category_id)&.id,
          amount_cents: original.amount_cents,
          payee: original.payee,
          notes: original.notes,
          date: Date.current,
          status: :cleared
        )
      end

      def duplicate_transfer(original)
        Current.household.transfers.new(
          from_account_id: open_account_id(original.from_account_id),
          to_account_id: open_account_id(original.to_account_id),
          amount_cents: original.amount_cents,
          notes: original.notes,
          date: Date.current
        )
      end

      def open_account_id(id)
        Current.household.accounts.open.find_by(id: id)&.id
      end
  end
end
