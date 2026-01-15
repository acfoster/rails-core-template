class AddArchivedAtToStrategies < ActiveRecord::Migration[8.0]
  def change
    add_column :strategies, :archived_at, :datetime
  end
end
