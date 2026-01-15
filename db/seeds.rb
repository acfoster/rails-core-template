# Seed data for Core App Template
SEED_PASSWORD = "password123"

if Rails.env.development?
  puts "Clearing existing data..."
  Log.destroy_all
  User.destroy_all
  puts "✓ Cleared existing data"
end

puts "\nCreating admin user..."
admin = User.find_or_create_by!(email: "admin@example.com") do |u|
  u.password = SEED_PASSWORD
  u.password_confirmation = SEED_PASSWORD
  u.role = :admin
  u.trial_ends_at = 365.days.from_now
  u.subscription_status = "active"
  u.confirmed_at = Time.current
end
puts "✓ Admin user created"
puts "  Email: #{admin.email}"
puts "  Password: #{SEED_PASSWORD}"
puts "  Role: #{admin.role}"

puts "\nCreating test user..."
user = User.find_or_create_by!(email: "test@example.com") do |u|
  u.password = SEED_PASSWORD
  u.password_confirmation = SEED_PASSWORD
  u.trial_ends_at = 30.days.from_now
  u.subscription_status = "trialing"
  u.confirmed_at = Time.current
end
puts "✓ Test user created"
puts "  Email: #{user.email}"
puts "  Password: #{SEED_PASSWORD}"

puts "\n----------------------------------------"
puts "DEVELOPMENT ONLY credentials"
puts "Seeded development users"
puts "Admin:"
puts "  Email: #{admin.email}"
puts "  Password: #{SEED_PASSWORD}"
puts "\nTest user:"
puts "  Email: #{user.email}"
puts "  Password: #{SEED_PASSWORD}"
puts "----------------------------------------"
puts "\n✅ Seed data created successfully!"
