class AddAiResponseMetadataToEvaluations < ActiveRecord::Migration[8.0]
  def change
    add_column :evaluations, :ai_response_metadata, :jsonb, default: {}, null: false
  end
end
