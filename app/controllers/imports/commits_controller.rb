module Imports
  # Confirmar un extracto revisado (US-0113): crea los movimientos, todos o ninguno
  class CommitsController < ApplicationController
    def create
      import = Current.household.imports.find(params[:import_id])
      result = Imports::Commit.call(import)

      if result.undecided_lines.any?
        redirect_to account_import_path(import.account_id, import), status: :see_other,
          error: t(".undecided", lines: result.undecided_lines.to_sentence)
      elsif result.failed_line
        redirect_to account_import_path(import.account_id, import), status: :see_other,
          error: t(".failed", line: result.failed_line)
      else
        redirect_to account_path(import.account_id), status: :see_other, success: t(".success", count: result.created)
      end
    end
  end
end
