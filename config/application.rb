require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Require custom middleware before application initialization
require_relative "../app/middleware/request_logger_middleware"
require_relative "../app/middleware/error_tracking_middleware"
require_relative "../app/middleware/bot_blocking_middleware"

module TradeBuddy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Add app/middleware to autoload paths
    config.autoload_paths << Rails.root.join("app/middleware")
    config.eager_load_paths << Rails.root.join("app/middleware")

    # Bot blocking, request logging and error tracking middleware
    config.middleware.use Rack::Attack
    config.middleware.use BotBlockingMiddleware  
    config.middleware.use RequestLoggerMiddleware
    config.middleware.use ErrorTrackingMiddleware
  end
end
