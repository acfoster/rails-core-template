class AddOptimizedIndexForDashboardPoll < ActiveRecord::Migration[8.0]
  def change
    # Index optimized for dashboard poll query: user_id + status + updated_at
    add_index :evaluations, [:user_id, :status, :updated_at] unless index_exists?(:evaluations, [:user_id, :status, :updated_at])
  end
end