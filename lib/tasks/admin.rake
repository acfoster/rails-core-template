namespace :admin do
  desc "Promote a user to admin by email"
  task :promote, [:email] => :environment do |t, args|
    email = args[:email] || ENV['EMAIL']

    unless email
      puts "Usage: rails admin:promote[user@example.com]"
      puts "   or: EMAIL=user@example.com rails admin:promote"
      exit 1
    end

    user = User.find_by(email: email)

    unless user
      puts "Error: User with email '#{email}' not found"
      exit 1
    end

    if user.admin?
      puts "User '#{email}' is already an admin"
    else
      user.update!(role: :admin)
      puts "Successfully promoted '#{email}' to admin"
    end
  end

  desc "Demote an admin user to regular user by email"
  task :demote, [:email] => :environment do |t, args|
    email = args[:email] || ENV['EMAIL']

    unless email
      puts "Usage: rails admin:demote[admin@example.com]"
      puts "   or: EMAIL=admin@example.com rails admin:demote"
      exit 1
    end

    user = User.find_by(email: email)

    unless user
      puts "Error: User with email '#{email}' not found"
      exit 1
    end

    unless user.admin?
      puts "User '#{email}' is not an admin"
    else
      user.update!(role: :user)
      puts "Successfully demoted '#{email}' to regular user"
    end
  end

  desc "List all admin users"
  task list: :environment do
    admins = User.admin

    if admins.empty?
      puts "No admin users found"
    else
      puts "Admin users:"
      admins.each do |admin|
        puts "  - #{admin.email} (ID: #{admin.id}, created: #{admin.created_at.to_date})"
      end
    end
  end
end
