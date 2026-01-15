class MakeRuleKeyNullable < ActiveRecord::Migration[8.0]
  def up
    # Remove NOT NULL constraint from rule_key
    # We're keeping the column for now but it's no longer required
    # All rule identification now uses rule_identifier (strategy_id_rule_id)
    change_column_null :strategy_rules, :rule_key, true

    # Remove uniqueness constraint
    remove_index :strategy_rules, [:strategy_id, :rule_key], if_exists: true
  end

  def down
    # Cannot re-add NOT NULL if there are null values
    # Cannot re-add unique index if there are null values
    raise ActiveRecord::IrreversibleMigration, "Cannot reverse making rule_key nullable once rules exist without it"
  end
end
