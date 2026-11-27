class TransactionsController < ApplicationController
  include Pagy::Method

  PER_PAGE = 50

  layout :modal_layout

  before_action :set_transaction, only: %i[ edit update destroy ]
  before_action :redirect_transfer_leg, only: %i[ edit update ]

  def index
    @search = TransactionSearch.new(household: Current.household, **search_params)
    # Una cuenta o categoría de otro hogar (o inexistente) da 404, como sus fichas
    raise ActiveRecord::RecordNotFound unless @search.valid_references?
    @pagy, @transactions = pagy(@search.results, limit: PER_PAGE)
  end

  def new
    @transaction = Current.household.transactions.new(
      date: Date.current,
      status: :cleared,
      direction: params[:direction].presence_in(Transaction::DIRECTIONS) || "expense",
      # Si no viene de la ficha de una cuenta, la última usada (se ignora si ya está cerrada)
      account_id: Current.household.accounts.open.find_by(id: params[:account_id] || cookies.signed[:last_account_id])&.id
    )
  end

  def create
    @transaction = Current.household.transactions.new(transaction_params)

    if @transaction.save
      remember_last_account(@transaction.account_id)
      return close_modal_and_refresh(t(".success")) if modal_request?

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
      @transaction = Current.household.transactions.with_attached_receipt.find(params[:id])
    end

    # Un lado de una transferencia se edita desde la transferencia, con los dos a la vez
    def redirect_transfer_leg
      redirect_to edit_transfer_path(@transaction.transfer_id) if @transaction.transfer?
    end

    def search_params
      params.permit(:month, :account_id, :category_id, :status, :q).to_h.symbolize_keys
    end

    def transaction_params
      params.expect(transaction: %i[ direction amount_input date account_id category_id status payee notes receipt ])
    end
end
