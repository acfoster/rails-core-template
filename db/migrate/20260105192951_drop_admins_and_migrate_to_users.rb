class DropAdminsAndMigrateToUsers < ActiveRecord::Migration[8.0]
  def up
    # Migrate any existing admins to users with admin role
    # This assumes admins table exists and has email/encrypted_password
    if table_exists?(:admins)
      execute <<-SQL
        INSERT INTO users (email, encrypted_password, role, created_at, updated_at)
        SELECT email, encrypted_password, 1, created_at, updated_at
        FROM admins
        WHERE email NOT IN (SELECT email FROM users)
      SQL

      drop_table :admins
    end
  end

  def down
    # Recreate admins table (from original devise migration structure)
    create_table :admins do |t|
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.timestamps null: false
    end

    add_index :admins, :email, unique: true
    add_index :admins, :reset_password_token, unique: true

    # Migrate admin users back to admins table
    execute <<-SQL
      INSERT INTO admins (email, encrypted_password, created_at, updated_at)
      SELECT email, encrypted_password, created_at, updated_at
      FROM users
      WHERE role = 1
    SQL
  end
end
