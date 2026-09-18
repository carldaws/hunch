class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.text :body
      t.integer :status

      t.timestamps
    end
  end
end
