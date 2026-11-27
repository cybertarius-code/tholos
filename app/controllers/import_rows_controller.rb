# Corregir una fila de un extracto cargado y decidir qué es (US-0113). Se
# envía desde su Turbo Frame y responde con la fila.
class ImportRowsController < ApplicationController
  def update
    @row = ImportRow.joins(:import).where(imports: { household_id: Current.household.id }).includes(:import).find(params[:id])
    return head :unprocessable_content if @row.locked?

    @row.commit_error = nil
    status = @row.update(row_params) ? :ok : :unprocessable_content
    render partial: "imports/row", locals: { row: @row }, status: status
  end

  private
    def row_params
      params.expect(import_row: %i[ date amount_input concept decision ])
    end
end
