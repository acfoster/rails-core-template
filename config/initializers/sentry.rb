# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Add data like request headers and IP for users
  config.send_default_pii = true

  # Set traces sample rate for performance monitoring
  config.traces_sample_rate = 1.0

  # Set the environment
  config.environment = Rails.env
end
