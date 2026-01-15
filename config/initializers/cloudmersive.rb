# frozen_string_literal: true

# The Cloudmersive gem has compatibility issues with Ruby 3.x
# Instead of using the gem, we use direct HTTP calls via Net::HTTP
# This is more reliable and doesn't have URI.encode issues

# Log configuration at startup
Rails.application.config.after_initialize do
  Rails.logger.info "[CLOUDMERSIVE_INIT] Configuration:"
  Rails.logger.info "[CLOUDMERSIVE_INIT]   Host: api.cloudmersive.com"
  Rails.logger.info "[CLOUDMERSIVE_INIT]   API Key Present: #{ENV['CLOUDMERSIVE_API_KEY'].present?}"
  Rails.logger.info "[CLOUDMERSIVE_INIT]   Using direct HTTP implementation (not gem)"
end
