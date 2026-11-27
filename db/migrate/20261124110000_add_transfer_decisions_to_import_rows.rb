# Decisiones de US-0114 en la revisión de un extracto: transferencia a/desde otra
# cuenta del hogar, o "ya registrado" (enlaza la fila con un movimiento que ya
# existe). Una fila tiene como mucho una decisión.
class AddTransferDecisionsToImportRows < ActiveRecord::Migration[8.1]
  def change
    add_reference :import_rows, :counter_account, foreign_key: { to_table: :accounts, on_delete: :nullify }
    add_reference :import_rows, :matched_transaction, foreign_key: { to_table: :transactions, on_delete: :nullify }

    remove_check_constraint :import_rows, "NOT (skipped AND category_id IS NOT NULL)", name: "import_rows_skipped_sin_categoria"
    add_check_constraint :import_rows,
      "skipped::int + num_nonnulls(category_id, counter_account_id, matched_transaction_id) <= 1",
      name: "import_rows_una_decision"
  end
end
