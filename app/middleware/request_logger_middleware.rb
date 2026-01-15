class RequestLoggerMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    start_time = Time.current

    # Process the request
    status, headers, response = @app.call(env)
    duration = ((Time.current - start_time) * 1000).round(2) # milliseconds

    # Skip logging if request was handled by bot blocking middleware
    unless bot_blocked_request?(env, status)
      log_request_outcome(env, request, status, duration)
    end

    [ status, headers, response ]
  rescue StandardError => e
    # Log errors with minimal user data
    user = current_user_from_env(env)
    error_context = {
      error: e.message,
      error_class: e.class.name,
      backtrace: e.backtrace&.first(5)
    }
    
    Log.log(
      log_type: 'error',
      level: 'error',
      message: "HTTP request error: #{e.message}",
      user_id: user&.id,
      action: 'http_request_error',
      controller: extract_controller(env),
      request_id: request&.request_id,
      ip_address: request&.remote_ip,
      context: limit_payload_size(error_context, 2048)
    )
    raise
  end

  private

  def bot_blocked_request?(env, status)
    # Check if request was blocked by bot blocking middleware
    # Bot blocking returns 404 or 410 with specific content type
    request = ActionDispatch::Request.new(env)
    path = request.path_info
    
    (status == 404 || status == 410) && 
    (path&.match?(/\/wp-|\.php$|\/admin|\/xmlrpc/) ||
     request.user_agent&.match?(/curl|wget|scanner|bot/i))
  end

  def current_user_from_env(env)
    # Try to get current user from warden (Devise)
    warden = env['warden']
    warden&.user if warden
  rescue StandardError
    nil
  end

  def extract_controller(env)
    # Extract controller name from the request
    env['action_dispatch.request.path_parameters']&.dig(:controller) || 'unknown'
  rescue StandardError
    'unknown'
  end

  def sanitize_params(params)
    # Remove sensitive parameters
    params.except('password', 'password_confirmation', 'authenticity_token', 'stripe_signature')
  rescue StandardError
    {}
  end

  def response_log_level(status)
    case status
    when 200..299
      'info'
    when 300..399
      'info'
    when 400..499
      'warning'
    when 500..599
      'error'
    else
      'info'
    end
  end

  def log_request_outcome(env, request, status, duration)
    user = current_user_from_env(env)
    
    # Use minimal user data - only user_id and basic info, never full object
    user_data = user ? {
      user_id: user.id,
      role: user.respond_to?(:admin?) && user.admin? ? 'admin' : 'user',
      subscription_status: user.respond_to?(:subscription_status) ? user.subscription_status : 'unknown'
    } : nil
    
    # Limit context payload size to prevent large JSON serialization
    base_context = {
      method: request.method,
      path: request.path,
      status: status,
      duration_ms: duration
    }
    
    # Cap total context size at 2KB
    limited_context = limit_payload_size(base_context, 2048)
    
    log_payload = {
      log_type: 'http_request',
      level: response_log_level(status),
      message: "HTTP request completed",
      user_id: user&.id,
      action: 'http_request_completed',
      controller: extract_controller(env),
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: limited_context,
      metadata: user_data
    }

    if status >= 400
      Log.log(**log_payload)
      return
    end

    if request_db_logging_enabled? && duration >= request_log_slow_threshold_ms
      Log.log(**log_payload.merge(level: 'warning', message: "HTTP request slow"))
      return
    end

    emit_request_log(log_payload)
  rescue StandardError => e
    Rails.logger.error("[REQUEST_LOGGER] Failed to log request: #{e.class} - #{e.message}")
  end

  def emit_request_log(payload)
    Rails.logger.info(payload.to_json)
  rescue StandardError
    Rails.logger.info("[REQUEST_LOGGER] Request log skipped")
  end

  def request_db_logging_enabled?
    return env_bool("REQUEST_DB_LOGGING_ENABLED", !Rails.env.production?)
  end

  def request_log_slow_threshold_ms
    env_int("REQUEST_LOG_SLOW_THRESHOLD_MS", 800)
  end

  def env_bool(key, default)
    value = ENV[key]
    return default if value.nil?

    normalized = value.to_s.strip.downcase
    return false if %w[false 0 no n].include?(normalized)
    return true if %w[true 1 yes y].include?(normalized)

    default
  end

  def env_int(key, default)
    value = ENV[key]
    return default if value.nil? || value.strip.empty?

    value.to_i
  end

  def limit_payload_size(data, max_bytes)
    json_str = JSON.generate(data)
    return data if json_str.bytesize <= max_bytes
    
    # If payload is too large, return truncated version
    {
      truncated: true,
      original_size: json_str.bytesize,
      preview: json_str[0...(max_bytes/2)]
    }
  rescue StandardError
    { truncated: true, error: 'payload_serialization_failed' }
  end
end
