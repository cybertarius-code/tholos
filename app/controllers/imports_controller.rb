# Importar el extracto de un banco en dos pasos (US-0113, ADR-0017): cargar y revisar
class ImportsController < ApplicationController
  before_action :set_account

  def new
  end

  # El fichero se lee en esta petición y no se guarda
  def create
    if @account.closed?
      redirect_to @account, error: t(".closed_account"), status: :see_other
      return
    end

    @result = Imports::Stage.call(account: @account, file: params[:file])
    if @result.success?
      redirect_to account_import_path(@account, @result.import), success: t(".success", count: ImportRow.where(import_id: @result.import.id).count), status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @import = @account.imports.find(params[:id])
    @rows = ImportRow.where(import_id: @import.id).includes(:category).order(:line).to_a
    @rows.each { |row| row.association(:import).target = @import }
  end

  private
    def set_account
      @account = Current.household.accounts.find(params[:account_id])
    end
end
