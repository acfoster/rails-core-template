# Seed data for Core App Template

if Rails.env.development?
  puts "Clearing existing data..."
  Log.destroy_all
  User.destroy_all
  puts "✓ Cleared existing data"
end

puts "\nCreating admin user..."
admin = User.find_or_create_by!(email: "admin@example.com") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :admin
  u.trial_ends_at = 365.days.from_now
  u.subscription_status = "active"
  u.confirmed_at = Time.current
end
puts "✓ Admin user created"
puts "  Email: #{admin.email}"
puts "  Password: password123"
puts "  Role: #{admin.role}"

puts "\nCreating test user..."
user = User.find_or_create_by!(email: "test@example.com") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
  u.trial_ends_at = 30.days.from_now
  u.subscription_status = "trialing"
  u.confirmed_at = Time.current
end
puts "✓ Test user created"
puts "  Email: #{user.email}"
puts "  Password: password123"

puts "\n✅ Seed data created successfully!"
