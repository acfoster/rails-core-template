class CleanupRemovedDomainTables < ActiveRecord::Migration[8.0]
  def up
    if table_exists?(:evaluations)
      remove_foreign_key :evaluations, :strategies, if_exists: true
      remove_foreign_key :evaluations, :users, if_exists: true
    end

    if table_exists?(:strategies)
      remove_foreign_key :strategies, :users, if_exists: true
    end

    if table_exists?(:strategy_rules)
      remove_foreign_key :strategy_rules, :strategies, if_exists: true
    end

    drop_table :strategy_rules, if_exists: true
    drop_table :evaluations, if_exists: true
    drop_table :strategies, if_exists: true

    remove_column :users, :evaluations_count if column_exists?(:users, :evaluations_count)
    remove_column :users, :evaluations_reset_at if column_exists?(:users, :evaluations_reset_at)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
