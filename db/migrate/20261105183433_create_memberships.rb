class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :household, null: false, foreign_key: true
      t.string :role, null: false, default: 'owner'
      t.boolean :is_admin, null: false, default: false
      t.timestamps
    end
    add_index :memberships, [ :user_id, :household_id ], unique: true
  end
end
