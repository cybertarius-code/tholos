# Claves que referencian las FK compuestas de transactions (US-0104): la BD
# garantiza que cuenta y categoría son del mismo hogar que el movimiento y que
# su moneda es la de la cuenta.
class AddTenantKeysToAccountsAndCategories < ActiveRecord::Migration[8.1]
  def change
    add_index :accounts, [ :id, :household_id ], unique: true
    add_index :accounts, [ :id, :currency ], unique: true
    add_index :categories, [ :id, :household_id ], unique: true
  end
end
