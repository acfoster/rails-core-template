class AddFieldResolutionToEvaluations < ActiveRecord::Migration[8.0]
  def change
    add_column :evaluations, :field_resolution, :jsonb
  end
end
