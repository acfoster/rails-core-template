class RemoveActiveFromStrategies < ActiveRecord::Migration[8.0]
  def change
    remove_column :strategies, :active, :boolean
  end
end
