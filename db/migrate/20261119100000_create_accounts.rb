class CreateAccounts < ActiveRecord::Migration[8.1]
  KINDS = %w[ checking savings cash ewallet credit_card loan investment other ].freeze
  STATUSES = %w[ open closed ].freeze

  def change
    create_table :accounts do |t|
      t.references :household, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.string :kind, null: false
      t.string :currency, limit: 3, null: false
      t.bigint :opening_balance_cents, null: false, default: 0
      t.date :opening_date, null: false
      t.string :status, null: false, default: "open"
      t.boolean :include_in_net_worth, null: false, default: true
      t.text :notes
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :accounts, [ :household_id, :status ]
    add_check_constraint :accounts, "kind IN (#{KINDS.map { |k| "'#{k}'" }.join(', ')})", name: "accounts_kind_check"
    add_check_constraint :accounts, "status IN (#{STATUSES.map { |s| "'#{s}'" }.join(', ')})", name: "accounts_status_check"
  end
end
