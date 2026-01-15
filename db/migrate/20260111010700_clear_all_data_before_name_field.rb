class ClearAllDataBeforeNameField < ActiveRecord::Migration[8.0]
  def up
    # This migration clears all data before the name field is added
    # Safe to run because no production users exist yet

    puts "🗑️  Clearing all existing data..."

    # Truncate all tables (respecting foreign key dependencies)
    execute "TRUNCATE users, strategies, strategy_rules, evaluations RESTART IDENTITY CASCADE"

    puts "✅ All data cleared successfully"
    puts "ℹ️  Admin user will need to be created manually after deployment"
  end

  def down
    # Cannot restore deleted data
    raise ActiveRecord::IrreversibleMigration
  end
end
