class CreateHouseholds < ActiveRecord::Migration[8.1]
  def change
    create_table :households do |t|
      t.string :name, null: false
      t.string :base_currency, limit: 3, null: false, default: 'EUR'
      t.timestamps
    end
  end
end
