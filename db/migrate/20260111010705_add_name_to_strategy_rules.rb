class AddNameToStrategyRules < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Add column as nullable
    add_column :strategy_rules, :name, :string, null: true

    # Step 2: Backfill existing records
    # Generate names like "Rule 1", "Rule 2", etc. per strategy
    execute <<-SQL
      WITH numbered_rules AS (
        SELECT
          id,
          strategy_id,
          ROW_NUMBER() OVER (PARTITION BY strategy_id ORDER BY id) as rule_number
        FROM strategy_rules
      )
      UPDATE strategy_rules
      SET name = 'Rule ' || numbered_rules.rule_number
      FROM numbered_rules
      WHERE strategy_rules.id = numbered_rules.id;
    SQL

    # Step 3: Make NOT NULL now that all records have values
    change_column_null :strategy_rules, :name, false

    # Step 4: Add unique index
    add_index :strategy_rules, [:strategy_id, :name], unique: true
  end

  def down
    remove_index :strategy_rules, [:strategy_id, :name]
    remove_column :strategy_rules, :name
  end
end
