namespace :db do
  desc "Nuke all data and recreate from scratch (DESTRUCTIVE)"
  task nuke_and_reset: :environment do
    # Require explicit confirmation via ENV var
    unless ENV['CONFIRM_NUKE'] == 'yes'
      puts "❌ This task requires CONFIRM_NUKE=yes environment variable"
      exit 1
    end

    puts "🗑️  Nuking all data..."

    # Delete all records in order (respecting foreign keys)
    ActiveRecord::Base.connection.execute("TRUNCATE users, logs RESTART IDENTITY CASCADE")

    puts "✅ All data deleted!"
    puts "👤 Creating admin user..."

    admin = User.create!(
      email: ENV.fetch('ADMIN_EMAIL', 'admin@example.com'),
      password: ENV.fetch('ADMIN_PASSWORD', 'ChangeMe123!'),
      password_confirmation: ENV.fetch('ADMIN_PASSWORD', 'ChangeMe123!'),
      subscription_status: 'active',
      free_access: true,
      account_suspended: false
    )

    puts "✅ Setup complete!"
    puts "   Admin email: #{admin.email}"
    puts ""
    puts "⚠️  IMPORTANT: Change the admin password after logging in!"
  end

  desc "Create admin user if it doesn't exist"
  task create_admin: :environment do
    email = ENV.fetch('ADMIN_EMAIL', 'admin@example.com')

    if User.exists?(email: email)
      puts "ℹ️  Admin user #{email} already exists"
      exit 0
    end

    puts "👤 Creating admin user..."
    admin = User.create!(
      email: email,
      password: ENV.fetch('ADMIN_PASSWORD', 'ChangeMe123!'),
      password_confirmation: ENV.fetch('ADMIN_PASSWORD', 'ChangeMe123!'),
      subscription_status: 'active',
      free_access: true,
      account_suspended: false
    )

    puts "✅ Admin user created!"
    puts "   Email: #{admin.email}"
  end
end
