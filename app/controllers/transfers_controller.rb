class TransfersController < ApplicationController
  before_action :set_transfer, only: %i[ edit update destroy ]

  def new
    @transfer = Current.household.transfers.new(date: Date.current, **preselected_accounts)
  end

  def create
    @transfer = Current.household.transfers.new(transfer_params)

    if @transfer.save
      redirect_to account_path(@transfer.from_account_id), success: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @transfer.update(transfer_params)
      redirect_to account_path(@transfer.from_account_id), success: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    from_account_id = @transfer.from_account_id
    @transfer.destroy!
    redirect_to account_path(from_account_id), success: t(".success"), status: :see_other
  end

  private
    def set_transfer
      @transfer = Current.household.transfers.includes(:legs).find(params[:id])
    end

    def transfer_params
      params.expect(transfer: %i[ from_account_id to_account_id amount_input date notes ])
    end

    # Desde la ficha de una cuenta: es el origen, salvo en tarjetas y préstamos,
    # donde lo normal es pagarlas (el destino)
    def preselected_accounts
      account = Current.household.accounts.open.find_by(id: params[:account_id])
      return {} unless account

      account.liability? ? { to_account_id: account.id } : { from_account_id: account.id }
    end
end
