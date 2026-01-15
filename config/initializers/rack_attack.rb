# Rack::Attack configuration for bot protection and rate limiting
require 'digest'

Rack::Attack.enabled = Rails.env.production? || ENV['ENABLE_RACK_ATTACK'] == 'true'

# Configure cache store
Rack::Attack.cache.store = Rails.cache

# Helper method to extract real IP (respects Cloudflare headers)
def self.real_ip(request)
  # Cloudflare passes real IP in CF-Connecting-IP or True-Client-IP
  cloudflare_ip = request.get_header('HTTP_CF_CONNECTING_IP') || request.get_header('HTTP_TRUE_CLIENT_IP')
  cloudflare_ip.presence || request.ip
end

# Custom throttle key that masks IP for privacy
def self.masked_ip_key(request)
  ip = real_ip(request)
  # Hash IP with app secret for stable anonymization
  hashed_ip = Digest::SHA256.hexdigest("#{Rails.application.secret_key_base}:#{ip}")[0..7]
  "ip:#{hashed_ip}"
end

# Suspicious bot probe paths - very restrictive
Rack::Attack.throttle('suspicious_paths_per_ip', limit: 5, period: 30.seconds) do |request|
  suspicious_patterns = [
    /\/wp-admin/i,
    /\/wordpress/i,
    /\.php$/i,
    /\/xmlrpc\.php/i,
    /\/wp-login\.php/i,
    /\/admin\.php/i,
    /\/config\.php/i,
    /\/setup-config\.php/i
  ]
  
  if suspicious_patterns.any? { |pattern| request.path.match?(pattern) }
    masked_ip_key(request)
  end
end

# POST to common bot targets - moderately restrictive  
Rack::Attack.throttle('bot_post_targets_per_ip', limit: 10, period: 60.seconds) do |request|
  bot_post_paths = %w[/ /admin /api /index.php /wp-admin /login.php]
  
  if request.post? && bot_post_paths.include?(request.path)
    masked_ip_key(request)
  end
end

# General rate limiting - more permissive for legitimate users
Rack::Attack.throttle('requests_per_ip', limit: 100, period: 60.seconds) do |request|
  masked_ip_key(request)
end

# Auth endpoints protection
Rack::Attack.throttle('auth_requests_per_ip', limit: 20, period: 300.seconds) do |request|
  auth_paths = ['/users/sign_in', '/users/password', '/users/sign_up', '/users/confirmation']
  
  if request.post? && auth_paths.any? { |path| request.path.start_with?(path) }
    masked_ip_key(request)
  end
end

# Custom response for throttled requests
Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env['rack.attack.match_data']
  now = match_data[:epoch_time]

  headers = {
    'Content-Type' => 'text/plain',
    'Retry-After' => match_data[:period].to_s,
    'X-RateLimit-Limit' => match_data[:limit].to_s,
    'X-RateLimit-Remaining' => '0',
    'X-RateLimit-Reset' => (now + (match_data[:period] - (now % match_data[:period]))).to_s
  }

  [429, headers, ['Rate limit exceeded. Please try again later.']]
end

# Logging for rate limit events
ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
  req = payload[:request]
  matched_rule = req.env['rack.attack.matched']

  # Extract real IP using our helper
  ip = req.get_header('HTTP_CF_CONNECTING_IP') || req.get_header('HTTP_TRUE_CLIENT_IP') || req.ip

  # Anonymize IP for logs
  hashed_ip = Digest::SHA256.hexdigest("#{Rails.application.secret_key_base}:#{ip}")[0..7]
  
  # Truncate user agent
  user_agent = req.user_agent&.first(120) || 'unknown'
  
  case req.env['rack.attack.match_type']
  when :throttle
    Rails.logger.warn(
      "[RACK_ATTACK] Rate limited: rule=#{matched_rule} " \
      "ip_hash=#{hashed_ip} path=#{req.path} method=#{req.request_method} " \
      "user_agent=\"#{user_agent}\""
    )
  end
end