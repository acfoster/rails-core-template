class CreateReleaseTaskRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :release_task_runs do |t|
      t.string :task_name, null: false
      t.string :status, null: false, default: 'pending'
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :release_task_runs, :task_name
    add_index :release_task_runs, :status
    add_index :release_task_runs, [:task_name, :status]
  end
end
