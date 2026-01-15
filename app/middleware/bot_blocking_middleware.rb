class BotBlockingMiddleware
  require 'digest'

  # Fast-track bot probe paths for immediate 404 (no Rails routing)
  FAST_BLOCK_PATHS = %r{
    ^/wp-admin/|              # WordPress admin
    ^/wp-login\.php|          # WordPress login
    ^/wp-content/|            # WordPress content
    ^/wp-includes/|           # WordPress includes
    ^/wordpress/|             # WordPress directory
    ^/xmlrpc\.php|            # WordPress XML-RPC
    ^/index\.php|             # Generic PHP index
    ^/admin\.php|             # Generic admin
    ^/config\.php|            # Config files
    ^/setup-config\.php|      # WordPress setup
    ^/install\.php|           # Install scripts
    ^/phpinfo\.php|           # PHP info
    ^/info\.php|              # Info files
    ^/phpmyadmin/|            # phpMyAdmin
    ^/pma/|                   # phpMyAdmin shorthand
    ^/mysql/|                 # MySQL interfaces
    ^/sql/|                   # SQL interfaces
    ^/\.env|                  # Environment files
    ^/\.git/|                 # Git directories
    ^/backup/|                # Backup directories
    ^/tmp/|                   # Temp directories
    ^/cgi-bin/                # CGI directories
  }x.freeze

  # Common bot/scanner patterns to block (remaining patterns)
  BLOCKED_PATHS = %r{
    ^/blog/wp-|               # WordPress in blog subdirectory
    ^/administrator|          # Joomla admin
    ^/admin/config|           # Drupal admin
    ^/old|                    # Old directories
    ^/test/|                  # Test directories
    ^/demo/|                  # Demo directories
    ^/sftp-config\.json|      # SFTP config
    \.bak$|                   # Backup files
    \.sql$|                   # SQL files
    \.log$                    # Log files (except when accessing logs properly)
  }x.freeze

  # User agents that are clearly bots/scanners
  BLOCKED_USER_AGENTS = %r{
    python-requests|          # Common bot library
    curl/|                    # Command line tool (often automated)
    wget|                     # Command line tool
    Go-http-client|           # Go HTTP client
    libwww-perl|              # Perl library
    Apache-HttpClient|        # Java HTTP client
    okhttp|                   # Another HTTP client
    Symfony|                  # Symfony HTTP client (often bots)
    zgrab|                    # Security scanner
    masscan|                  # Port scanner
    nmap|                     # Network mapper
    sqlmap|                   # SQL injection tool
    nikto|                    # Web scanner
    dirb|                     # Directory bruter
    gobuster|                 # Directory bruter
    dirbuster                 # Directory bruter
  }xi.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    
    # Fast-track blocking for common bot probe paths - no Rails routing
    if fast_blocked_path?(request.path_info)
      return fast_block_request(request, "fast_blocked_path")
    end
    
    # Check if path matches other blocked patterns
    if blocked_path?(request.path_info)
      return block_request(request, "blocked_path")
    end
    
    # Check if user agent matches blocked patterns  
    if blocked_user_agent?(request.user_agent)
      return block_request(request, "blocked_user_agent")
    end
    
    # Check for suspicious query parameters
    if suspicious_query_params?(request.query_string)
      return block_request(request, "suspicious_params")
    end

    @app.call(env)
  end

  private

  def fast_blocked_path?(path)
    path&.match?(FAST_BLOCK_PATHS)
  end

  def blocked_path?(path)
    # Allow legitimate well-known paths (needed for SSL verification, etc.)
    return false if path&.start_with?('/.well-known/')
    
    path&.match?(BLOCKED_PATHS)
  end

  def blocked_user_agent?(user_agent)
    return false if user_agent.blank?
    
    # Allow legitimate browsers and crawlers
    return false if legitimate_user_agent?(user_agent)
    
    user_agent.match?(BLOCKED_USER_AGENTS)
  end

  def legitimate_user_agent?(user_agent)
    user_agent.match?(%r{
      Mozilla/|                 # Real browsers
      Chrome/|                  # Chrome
      Safari/|                  # Safari  
      Edge/|                    # Edge
      Firefox/|                 # Firefox
      Googlebot|                # Google crawler
      bingbot|                  # Bing crawler
      facebookexternalhit|      # Facebook crawler
      Twitterbot|               # Twitter crawler
      LinkedInBot|              # LinkedIn crawler
      WhatsApp|                 # WhatsApp preview
      Slackbot|                 # Slack preview
      Discordbot|               # Discord preview
      TelegramBot               # Telegram preview
    }xi)
  end

  def suspicious_query_params?(query_string)
    return false if query_string.blank?
    
    query_string.match?(%r{
      \.\./|                    # Directory traversal
      <script|                  # XSS attempts
      javascript:|              # XSS attempts  
      union.*select|            # SQL injection
      drop.*table|              # SQL injection
      insert.*into|             # SQL injection
      delete.*from|             # SQL injection
      exec\(|                   # Code execution
      system\(|                 # System calls
      passthru\(|               # PHP execution
      base64_decode|            # Encoding attacks
      eval\(|                   # Code execution (eval)
      file_get_contents         # File inclusion
    }xi)
  end

  def block_request(request, reason)
    # Log with masked IP and truncated user agent
    ip = extract_real_ip(request)
    masked_ip = mask_ip(ip)
    user_agent = request.user_agent&.slice(0, 120) || 'unknown'
    
    Rails.logger.info(
      "[BOT_BLOCKED] reason=#{reason} method=#{request.request_method} " \
      "path=#{request.path_info} ip=#{masked_ip} ua=\"#{user_agent}\""
    )
    
    # Return 404 to avoid revealing we're blocking them
    [404, {
      'Content-Type' => 'text/plain',
      'Cache-Control' => 'no-cache'
    }, ['Not Found']]
  end

  def fast_block_request(request, reason)
    # Same as block_request but optimized for speed - minimal logging
    ip = extract_real_ip(request)
    masked_ip = mask_ip(ip)
    
    Rails.logger.info(
      "[BOT_FAST_BLOCK] reason=#{reason} method=#{request.request_method} " \
      "path=#{request.path_info} ip=#{masked_ip}"
    )
    
    # Return 410 Gone for probe paths to discourage further attempts
    [410, {
      'Content-Type' => 'text/plain',
      'Cache-Control' => 'no-cache'
    }, ['Gone']]
  end

  def extract_real_ip(request)
    # Same logic as rack-attack for consistency
    cloudflare_ip = request.get_header('HTTP_CF_CONNECTING_IP') || 
                   request.get_header('HTTP_TRUE_CLIENT_IP')
    cloudflare_ip.presence || request.ip
  end

  def mask_ip(ip)
    # Hash IP with app secret for stable anonymization
    return 'unknown' if ip.blank?
    
    hashed = Digest::SHA256.hexdigest("#{Rails.application.secret_key_base}:#{ip}")
    "#{hashed[0..7]}"
  end
end
