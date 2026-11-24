class AccountsController < ApplicationController
  before_action :set_account, only: %i[ show edit update destroy ]

  # Abiertas agrupadas por clasificación y cerradas aparte; todos los saldos
  # en una sola consulta (Account.balances_for)
  def index
    @accounts = Current.household.accounts.ordered.to_a
    @balances = Account.balances_for(@accounts)
    open_accounts, @closed_accounts = @accounts.partition(&:open?)
    grouped = open_accounts.group_by(&:classification)
    @groups = Account::GROUPS.filter_map do |classification, group|
      [ group, grouped[classification] ] if grouped[classification]
    end
  end

  def show
    @balance_cents = @account.balance_cents
    @projected_balance_cents = @account.projected_balance_cents
    @daily_balances = @account.daily_balances
    @transactions = @account.transactions.includes(:category, transfer: { legs: :account }).recent_first.limit(20)
  end

  def new
    @account = Current.household.accounts.new(
      kind: :checking,
      currency: Current.household.base_currency,
      opening_date: Date.current
    )
  end

  def create
    @account = Current.household.accounts.new(account_params)

    if @account.save
      redirect_to @account, success: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @account.update(account_params)
      redirect_to @account, success: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @account.destroy
      redirect_to accounts_path, success: t(".success"), status: :see_other
    else
      redirect_to @account, error: t(".has_movements"), status: :see_other
    end
  end

  private
    def set_account
      @account = Current.household.accounts.find(params[:id])
    end

    def account_params
      params.expect(account: [ :name, :kind, :currency, :opening_amount, :opening_date, :include_in_net_worth, :notes ])
    end
end
