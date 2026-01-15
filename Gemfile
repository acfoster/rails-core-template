source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"

# Authentication
gem "devise", "~> 4.9"

# Email delivery via Resend
gem "resend", "~> 0.11"

# Payments
gem "stripe", "~> 12.0"

# OpenAI API
gem "ruby-openai", "~> 7.0"

# Anthropic API (Claude)
gem "anthropic", "~> 0.3.0"

# Error tracking
gem "sentry-ruby", "~> 5.18"
gem "sentry-rails", "~> 5.18"

# Image processing for ActiveStorage
gem "image_processing", "~> 1.2"

# Pagination
gem "kaminari", "~> 1.2"

# PDF generation
gem "wicked_pdf", "~> 2.8"
# Note: Using system wkhtmltopdf installed via nixpacks (Railway) instead of gem binary

# Virus scanning - Cloudmersive API (cloud-based, no memory issues)
gem "cloudmersive-virus-scan-api-client", "~> 2.0.3"

# Bot protection and rate limiting
gem "rack-attack", "~> 6.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw mswin x64_mingw ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Testing framework
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.4"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # Test helpers
  gem "shoulda-matchers", "~> 7.0"
  gem "webmock", "~> 3.23"
  gem "vcr", "~> 6.2"

  # Pin minitest to 5.x for Rails 8.0 compatibility
  gem "minitest", "~> 5.25"
end
