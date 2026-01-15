module LoggableActions
  extend ActiveSupport::Concern

  included do
    # Skip after_action logging for paths that already have comprehensive middleware logging
    # This prevents duplicate logs for the same request
    after_action :log_request_response, unless: -> { 
      request.path.start_with?('/assets', '/rails/active_storage') ||
      skip_duplicate_logging?
    }
  end

  private

  def skip_duplicate_logging?
    # Skip controller-level logging for paths that get comprehensive logging elsewhere
    skip_paths = %w[/dashboard_poll /health /up]
    skip_paths.include?(request.path)
  end

  def log_request_response
    # Use minimal user data to avoid large JSON serialization
    user_id = current_user&.id
    
    # Limit params to prevent large payload
    limited_context = {
      method: request.method,
      path: request.path,
      status: response.status,
      params: limit_params_for_logging(filtered_params),
      user_agent: request.user_agent&.truncate(200)
    }

    Log.log(
      log_type: 'http_request',
      level: response.successful? ? 'info' : 'warning',
      message: "#{request.method} #{request.path}",
      user_id: user_id,
      action: "#{controller_name}_#{action_name}",
      controller: controller_name,
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: limited_context
    )
  rescue StandardError => e
    # Don't let logging errors break the request
    Rails.logger.error("[LOGGING_ERROR] Failed to log request: #{e.message}")
    Sentry.capture_exception(e) if defined?(Sentry)
  end

  def filtered_params
    # Remove sensitive params
    params.except(:authenticity_token, :password, :password_confirmation, :current_password).to_unsafe_h
  end

  def limit_params_for_logging(params)
    # Limit params payload to prevent large JSON (e.g. image uploads)
    json_str = JSON.generate(params)
    return params if json_str.bytesize <= 1024 # 1KB limit
    
    {
      truncated: true,
      size: json_str.bytesize,
      keys: params.keys.map(&:to_s)
    }
  rescue StandardError
    { truncated: true, error: 'params_serialization_failed' }
  end
end
