class CreateStrategies < ActiveRecord::Migration[8.0]
  def change
    create_table :strategies do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :active, default: true, null: false
      t.boolean :default, default: false, null: false

      t.timestamps
    end

    add_index :strategies, [ :user_id, :name ]
    add_index :strategies, [ :user_id, :default ]
  end
end
