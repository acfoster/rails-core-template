class CreateStrategyRules < ActiveRecord::Migration[8.0]
  def change
    create_table :strategy_rules do |t|
      t.references :strategy, null: false, foreign_key: true
      t.string :rule_key, null: false
      t.text :description, null: false
      t.text :evaluation_hint, null: false
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end

    add_index :strategy_rules, [ :strategy_id, :rule_key ], unique: true
  end
end
