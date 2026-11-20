module Accounts
  class ClosuresController < ApplicationController
    before_action :set_account

    # Cerrar: se permite con saldo distinto de cero, pero se avisa
    def create
      @account.close!

      if @account.balance_cents.zero?
        redirect_to @account, success: t(".success"), status: :see_other
      else
        redirect_to @account, warning: t(".success_with_balance"), status: :see_other
      end
    end

    # Reabrir
    def destroy
      @account.reopen!
      redirect_to @account, success: t(".success"), status: :see_other
    end

    private
      def set_account
        @account = Current.household.accounts.find(params[:account_id])
      end
  end
end
