class CreateLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :logs do |t|
      t.string :log_type, null: false
      t.string :level, null: false
      t.string :action
      t.text :message, null: false
      t.references :user, foreign_key: true
      t.string :controller
      t.string :request_id
      t.string :ip_address
      t.jsonb :context, default: {}
      t.jsonb :metadata, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :logs, :log_type
    add_index :logs, :level
    add_index :logs, :action
    add_index :logs, :occurred_at
    add_index :logs, :request_id
    add_index :logs, [:log_type, :level, :occurred_at]
  end
end
