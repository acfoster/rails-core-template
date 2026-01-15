class AddUsageTrackingToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :evaluations_count, :integer, default: 0, null: false
    add_column :users, :evaluations_reset_at, :datetime
    add_column :users, :free_access, :boolean, default: false, null: false
    add_column :users, :account_suspended, :boolean, default: false, null: false
    add_column :users, :discount_percentage, :integer, default: 0, null: false
  end
end
