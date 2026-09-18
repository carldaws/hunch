class CreateSignups < ActiveRecord::Migration[8.1]
  def change
    create_table :signups do |t|
      t.string :email
      t.string :address
      t.text :bio

      t.timestamps
    end
  end
end
