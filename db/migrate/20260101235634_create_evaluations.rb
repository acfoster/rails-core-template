class CreateEvaluations < ActiveRecord::Migration[8.0]
  def change
    create_table :evaluations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :strategy, null: false, foreign_key: true
      t.jsonb :ai_result, default: {}
      t.string :confluence_score
      t.string :classification

      t.timestamps
    end

    add_index :evaluations, :created_at
    add_index :evaluations, [ :user_id, :created_at ]
  end
end
