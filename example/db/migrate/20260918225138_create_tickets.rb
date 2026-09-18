class CreateTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :tickets do |t|
      t.string :team
      t.string :subject
      t.text :body

      t.timestamps
    end
  end
end
