class AddMetadataToEvaluations < ActiveRecord::Migration[8.0]
  def change
    add_column :evaluations, :market, :string
    add_column :evaluations, :execution_timeframe, :string
    add_column :evaluations, :htf_bias, :string
    add_column :evaluations, :assumptions, :text
    add_column :evaluations, :prompt_version, :string
    add_column :evaluations, :ruleset_version, :string
    add_column :evaluations, :ai_model_name, :string
    add_column :evaluations, :ai_response_text, :text
    add_column :evaluations, :image_deleted_at, :datetime
  end
end
