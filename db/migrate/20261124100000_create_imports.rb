# Importación bancaria en dos pasos (US-0113, ADR-0017): un extracto cargado y
# sus filas, que no cuentan hasta confirmarlas (PRD-F1 §5).
class CreateImports < ActiveRecord::Migration[8.1]
  def change
    create_table :imports do |t|
      t.bigint :household_id, null: false
      t.bigint :account_id, null: false
      t.string :status, null: false, default: "staged"
      t.string :filename
      t.datetime :confirmed_at
      t.timestamps
    end

    add_index :imports, :household_id
    add_index :imports, :account_id
    add_foreign_key :imports, :households
    # La cuenta, del mismo hogar que la importación
    add_foreign_key :imports, :accounts, column: [ :account_id, :household_id ],
      primary_key: [ :id, :household_id ], on_delete: :restrict, name: "imports_account_household_fk"
    add_check_constraint :imports, "status IN ('staged', 'confirmed')", name: "imports_status_check"

    create_table :import_rows do |t|
      t.references :import, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :line, null: false
      t.date :date, null: false
      t.string :concept, null: false
      t.bigint :amount_cents, null: false
      t.bigint :balance_cents, null: false
      # Huella de la fila tal como vino del banco: no cambia al corregirla
      t.string :import_ref, null: false
      t.string :proposal, null: false, default: "none"
      t.boolean :skipped, null: false, default: false
      t.references :category, foreign_key: { on_delete: :nullify }
      t.text :commit_error
      t.timestamps
    end

    add_index :import_rows, [ :import_id, :line ], unique: true
    add_check_constraint :import_rows, "proposal IN ('none', 'duplicate', 'before_cutoff')", name: "import_rows_proposal_check"
    # Omitida o con categoría, nunca las dos
    add_check_constraint :import_rows, "NOT (skipped AND category_id IS NOT NULL)", name: "import_rows_skipped_sin_categoria"

    add_column :transactions, :import_ref, :string
    add_index :transactions, :import_ref, unique: true
  end
end
