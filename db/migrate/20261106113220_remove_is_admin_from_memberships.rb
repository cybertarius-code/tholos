class RemoveIsAdminFromMemberships < ActiveRecord::Migration[8.1]
  def change
    # El rol `admin` del enum `role` ya cubre este dato
    remove_column :memberships, :is_admin, :boolean, null: false, default: false
  end
end
