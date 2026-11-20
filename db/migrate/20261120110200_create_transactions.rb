# Libro mayor (PRD-F1 §5, ADR-0004 y ADR-0014).
class CreateTransactions < ActiveRecord::Migration[8.1]
  STATUSES = %w[ scheduled pending cleared ].freeze

  def change
    create_table :transactions do |t|
      t.bigint :household_id, null: false
      t.bigint :account_id, null: false
      t.bigint :category_id
      t.bigint :amount_cents, null: false
      t.string :currency, limit: 3, null: false
      t.date :date, null: false
      t.string :status, null: false, default: "cleared"
      t.string :payee
      t.text :notes
      t.references :transfer, foreign_key: { on_delete: :restrict }, index: false
      t.boolean :adjustment, null: false, default: false
      t.timestamps
    end

    add_index :transactions, [ :account_id, :date ]
    add_index :transactions, [ :household_id, :date ]
    add_index :transactions, [ :category_id, :date ]
    # Como mucho una salida y una entrada por transferencia
    add_index :transactions, "transfer_id, (amount_cents > 0)", unique: true,
      where: "transfer_id IS NOT NULL", name: "transactions_un_lado_por_signo"

    add_foreign_key :transactions, :households
    # Cuenta y categoría del mismo hogar; moneda = la de la cuenta (y la cuenta
    # no puede cambiar de moneda mientras tenga movimientos)
    add_foreign_key :transactions, :accounts, column: [ :account_id, :household_id ],
      primary_key: [ :id, :household_id ], on_delete: :restrict, name: "transactions_account_household_fk"
    add_foreign_key :transactions, :accounts, column: [ :account_id, :currency ],
      primary_key: [ :id, :currency ], on_delete: :restrict, name: "transactions_account_currency_fk"
    add_foreign_key :transactions, :categories, column: [ :category_id, :household_id ],
      primary_key: [ :id, :household_id ], on_delete: :restrict, name: "transactions_category_household_fk"

    add_check_constraint :transactions, "amount_cents <> 0", name: "transactions_importe_no_cero"
    add_check_constraint :transactions, "status IN (#{STATUSES.map { |s| "'#{s}'" }.join(', ')})",
      name: "transactions_status_check"
    # ADR-0014 A: transferencia, ajuste o ingreso/gasto; nunca dos a la vez
    add_check_constraint :transactions, "num_nonnulls(transfer_id, NULLIF(adjustment, false), category_id) <= 1",
      name: "transactions_un_solo_tipo"
  end
end
