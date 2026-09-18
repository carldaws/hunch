class ReplaceAddressWithDisplayNameOnSignups < ActiveRecord::Migration[8.1]
  def change
    remove_column :signups, :address, :string
    add_column :signups, :display_name, :string
  end
end
