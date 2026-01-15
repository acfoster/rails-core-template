class BackfillConfirmedAtAndAddEmailIndex < ActiveRecord::Migration[8.0]
  def up
    # Backfill confirmed_at for all existing users (they were created before confirmable was enabled)
    User.where(confirmed_at: nil).update_all(confirmed_at: Time.current)

    # Add case-insensitive unique index on email
    # First, check if there's an existing standard email index and remove it if needed
    if index_exists?(:users, :email)
      remove_index :users, :email
    end

    # Add the new case-insensitive index
    execute <<-SQL
      CREATE UNIQUE INDEX index_users_on_lower_email ON users (LOWER(email));
    SQL
  end

  def down
    # Remove case-insensitive index
    execute <<-SQL
      DROP INDEX IF EXISTS index_users_on_lower_email;
    SQL

    # Restore standard email index
    add_index :users, :email, unique: true unless index_exists?(:users, :email)
  end
end
