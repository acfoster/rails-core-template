class AddVisionAnalysisToEvaluations < ActiveRecord::Migration[8.0]
  def change
    add_column :evaluations, :vision_analysis, :text
  end
end
