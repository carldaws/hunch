class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.string :reference
      t.integer :status

      t.timestamps
    end
  end
end
