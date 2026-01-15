class ErrorTrackingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    start_time = Time.current
    
    begin
      status, headers, response = @app.call(env)
      duration_ms = ((Time.current - start_time) * 1000).round(2)
      
      # Log slow requests
      if duration_ms > 5000  # More than 5 seconds
        ApplicationLogger.log_warning(
          "Slow request detected",
          category: "performance",
          data: {
            method: request.method,
            path: request.path,
            duration_ms: duration_ms,
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          }
        )
      end
      
      # Log 4xx and 5xx responses
      if status >= 400
        error_type = case status
                    when 400..499 then "client_error"
                    when 500..599 then "server_error"
                    else "unknown_error"
                    end
                    
        ApplicationLogger.log_warning(
          "HTTP error response: #{status}",
          category: "http_error", 
          data: {
            method: request.method,
            path: request.path,
            status: status,
            duration_ms: duration_ms,
            ip_address: request.remote_ip,
            user_agent: request.user_agent,
            error_type: error_type
          }
        )
      end
      
      [status, headers, response]
      
    rescue => error
      duration_ms = ((Time.current - start_time) * 1000).round(2)
      
      ApplicationLogger.log_error(
        error,
        context: {
          component: "middleware",
          error_type: "request_processing_error",
          method: request.method,
          path: request.path,
          duration_ms: duration_ms,
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
          params: sanitize_params(request.params)
        }
      )
      
      Log.log(
        log_type: 'error',
        level: 'error',
        message: "Middleware caught error: #{error.message}",
        action: 'middleware_error',
        ip_address: request.remote_ip,
        context: {
          error_class: error.class.name,
          method: request.method,
          path: request.path,
          backtrace: error.backtrace&.first(10),
          duration_ms: duration_ms
        }
      )
      
      raise error
    end
  end
  
  private
  
  def sanitize_params(params)
    # Remove sensitive data from params for logging
    sanitized = params.except("password", "password_confirmation", "authenticity_token", "current_password")
    # Truncate large values to prevent log bloat
    sanitized.transform_values do |value|
      if value.is_a?(String) && value.length > 1000
        "#{value[0..997]}..."
      else
        value
      end
    end
  end
end