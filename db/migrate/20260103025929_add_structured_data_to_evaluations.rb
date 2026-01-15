class AddStructuredDataToEvaluations < ActiveRecord::Migration[8.0]
  def change
    add_column :evaluations, :rule_evaluations, :jsonb
    add_column :evaluations, :key_observations, :text
    add_column :evaluations, :risk_factors, :text
    add_column :evaluations, :educational_notes, :text
    add_column :evaluations, :overall_assessment, :text
    add_column :evaluations, :confidence_level, :string
    add_column :evaluations, :tags, :string
  end
end
