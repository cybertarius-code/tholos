module Accounts
  # Ajustar el saldo de una cuenta al real del banco (US-0108)
  class AdjustmentsController < ApplicationController
    before_action :set_account

    def new
      @adjustment = BalanceAdjustment.new(account: @account)
    end

    def create
      @adjustment = BalanceAdjustment.new(adjustment_params.merge(account: @account))

      if !@adjustment.save
        render :new, status: :unprocessable_content
      elsif @adjustment.movement
        redirect_to @account, success: t(".success"), status: :see_other
      else
        redirect_to @account, info: t(".unchanged"), status: :see_other
      end
    end

    private
      # Una cuenta cerrada no admite movimientos nuevos
      def set_account
        @account = Current.household.accounts.open.find(params[:account_id])
      end

      def adjustment_params
        params.expect(adjustment: %i[ amount_input date ])
      end
  end
end
