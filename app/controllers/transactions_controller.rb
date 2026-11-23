class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[ edit update destroy ]
  before_action :redirect_transfer_leg, only: %i[ edit update ]

  def new
    @transaction = Current.household.transactions.new(
      date: Date.current,
      status: :cleared,
      direction: params[:direction].presence_in(Transaction::DIRECTIONS) || "expense",
      account_id: Current.household.accounts.open.find_by(id: params[:account_id])&.id
    )
  end

  def create
    @transaction = Current.household.transactions.new(transaction_params)

    if @transaction.save
      redirect_to account_path(@transaction.account_id), success: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @transaction.update(transaction_params)
      redirect_to account_path(@transaction.account_id), success: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @transaction.destroy!
    redirect_to account_path(@transaction.account_id), success: t(".success"), status: :see_other
  end

  private
    def set_transaction
      @transaction = Current.household.transactions.find(params[:id])
    end

    # Un lado de una transferencia se edita desde la transferencia, con los dos a la vez
    def redirect_transfer_leg
      redirect_to edit_transfer_path(@transaction.transfer_id) if @transaction.transfer?
    end

    def transaction_params
      params.expect(transaction: %i[ direction amount_input date account_id category_id status payee notes ])
    end
end
