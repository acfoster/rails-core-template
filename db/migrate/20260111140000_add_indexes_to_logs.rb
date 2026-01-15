class AddIndexesToLogs < ActiveRecord::Migration[8.0]
  def change
    add_index :logs, :occurred_at unless index_exists?(:logs, :occurred_at)
    add_index :logs, :request_id unless index_exists?(:logs, :request_id)
    add_index :logs, [:user_id, :occurred_at] unless index_exists?(:logs, [:user_id, :occurred_at])
    add_index :logs, [:log_type, :occurred_at] unless index_exists?(:logs, [:log_type, :occurred_at])
  end
end
