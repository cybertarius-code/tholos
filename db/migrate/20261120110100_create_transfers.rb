# Cabecera de una transferencia: sus dos lados la apuntan con
# transactions.transfer_id (ADR-0004). La usa US-0105.
class CreateTransfers < ActiveRecord::Migration[8.1]
  def change
    create_table :transfers do |t|
      t.references :household, null: false, foreign_key: true
      t.timestamps
    end
  end
end
