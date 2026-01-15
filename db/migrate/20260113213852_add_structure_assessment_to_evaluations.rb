class AddStructureAssessmentToEvaluations < ActiveRecord::Migration[7.0]
  def change
    add_column :evaluations, :structure_assessment, :jsonb, default: {}
  end
end
