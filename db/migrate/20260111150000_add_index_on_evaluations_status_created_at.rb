class AddIndexOnEvaluationsStatusCreatedAt < ActiveRecord::Migration[8.0]
  def change
    add_index :evaluations, [:status, :created_at] unless index_exists?(:evaluations, [:status, :created_at])
  end
end
