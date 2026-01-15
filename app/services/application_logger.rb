class ApplicationLogger
  class << self
    # Log and capture error with comprehensive context
    def log_error(error, context: {}, user: nil, component: nil, severity: :error)
      error_type = context.delete(:error_type) || error.class.name

      # Build comprehensive log message
      log_message = build_log_message(error, context, component)

      # Log to Rails logger
      case severity
      when :fatal
        Rails.logger.fatal(log_message)
      when :error
        Rails.logger.error(log_message)
      when :warn
        Rails.logger.warn(log_message)
      else
        Rails.logger.info(log_message)
      end

      # Log backtrace
      if error.backtrace.present?
        Rails.logger.error("[BACKTRACE] #{error.backtrace.first(15).join("\n")}")
      end

      # Write to database
      Log.log(
        log_type: "error",
        level: map_severity_to_level(severity),
        message: log_message,
        user: user,
        action: component,
        controller: context[:controller],
        request_id: context[:request_id],
        ip_address: context[:ip_address],
        context: context.except(:controller, :request_id, :ip_address),
        metadata: {
          error_class: error.class.name,
          error_message: error.message,
          backtrace: error.backtrace&.first(15)
        }
      )

      # Capture in Sentry with full context
      Sentry.capture_exception(error) do |scope|
        # Set tags for filtering
        scope.set_tags(
          component: component || "unknown",
          error_type: error_type,
          severity: severity
        )

        # Set user context if available
        if user
          scope.set_user(
            id: user.id,
            email: user.email,
            username: user.email
          )
        end

        # Add all context data
        scope.set_context("details", context) if context.any?

        # Add environment info
        scope.set_context("environment", {
          rails_env: Rails.env,
          hostname: Socket.gethostname,
          timestamp: Time.current.iso8601
        })
      end
    end

    # Log info event with Sentry breadcrumb
    def log_info(message, category:, data: {}, user: nil)
      Rails.logger.info("[#{category.upcase}] #{message} #{format_data(data)}")

      # Write to database
      Log.log(
        log_type: category,
        level: "info",
        message: message,
        user: user,
        action: category,
        controller: data[:controller],
        request_id: data[:request_id],
        ip_address: data[:ip_address],
        context: data.except(:controller, :request_id, :ip_address)
      )

      Sentry.add_breadcrumb(Sentry::Breadcrumb.new(
        category: category,
        message: message,
        level: "info",
        data: data.merge(user_id: user&.id, timestamp: Time.current.iso8601)
      ))
    end

    # Log warning with Sentry breadcrumb
    def log_warning(message, category:, data: {}, user: nil)
      Rails.logger.warn("[#{category.upcase}] #{message} #{format_data(data)}")

      # Write to database
      Log.log(
        log_type: category,
        level: "warning",
        message: message,
        user: user,
        action: category,
        controller: data[:controller],
        request_id: data[:request_id],
        ip_address: data[:ip_address],
        context: data.except(:controller, :request_id, :ip_address)
      )

      Sentry.add_breadcrumb(Sentry::Breadcrumb.new(
        category: category,
        message: message,
        level: "warning",
        data: data.merge(user_id: user&.id, timestamp: Time.current.iso8601)
      ))
    end

    # Log HTTP request/response
    def log_http_request(method:, url:, status: nil, duration: nil, context: {})
      message = "[HTTP] #{method.upcase} #{url}"
      message += " - Status: #{status}" if status
      message += " - Duration: #{duration}ms" if duration
      message += " #{format_data(context)}"

      level = (status && status >= 400) ? "error" : "info"

      if status && status >= 400
        Rails.logger.error(message)
      else
        Rails.logger.info(message)
      end

      # Write to database
      Log.log(
        log_type: "http_request",
        level: level,
        message: message,
        user: context[:user],
        controller: context[:controller],
        request_id: context[:request_id],
        ip_address: context[:ip_address],
        context: {
          method: method,
          url: url,
          status: status,
          duration_ms: duration
        }.merge(context.except(:user, :controller, :request_id, :ip_address))
      )

      Sentry.add_breadcrumb(Sentry::Breadcrumb.new(
        category: "http",
        message: "#{method.upcase} #{url}",
        level: level,
        data: {
          method: method,
          url: url,
          status: status,
          duration_ms: duration
        }.merge(context)
      ))
    end

    # Log user action
    def log_user_action(action:, user:, details: {})
      message = "[USER_ACTION] #{user.email} - #{action}"
      Rails.logger.info("#{message} #{format_data(details)}")

      # Write to database
      Log.log(
        log_type: "user_action",
        level: "info",
        message: message,
        user: user,
        action: action,
        controller: details[:controller],
        request_id: details[:request_id],
        ip_address: details[:ip_address],
        context: details.except(:controller, :request_id, :ip_address)
      )

      Sentry.add_breadcrumb(Sentry::Breadcrumb.new(
        category: "user_action",
        message: action,
        level: "info",
        data: {
          user_id: user.id,
          user_email: user.email,
          action: action,
          timestamp: Time.current.iso8601
        }.merge(details)
      ))
    end

    # Log database query performance
    def log_slow_query(sql:, duration:, context: {})
      message = "[SLOW_QUERY] Duration: #{duration}ms - #{sql.truncate(200)}"
      Rails.logger.warn(message)

      # Write to database
      Log.log(
        log_type: "database_query",
        level: "warning",
        message: message,
        user: context[:user],
        controller: context[:controller],
        request_id: context[:request_id],
        ip_address: context[:ip_address],
        context: {
          sql: sql.truncate(500),
          duration_ms: duration
        }.merge(context.except(:user, :controller, :request_id, :ip_address))
      )

      Sentry.add_breadcrumb(Sentry::Breadcrumb.new(
        category: "database",
        message: "Slow query detected",
        level: "warning",
        data: {
          sql: sql.truncate(500),
          duration_ms: duration
        }.merge(context)
      ))
    end

    private

    def build_log_message(error, context, component)
      parts = []
      parts << "[#{component.upcase}]" if component
      parts << "[ERROR]"
      parts << "#{error.class.name}:"
      parts << error.message
      parts << format_data(context) if context.any?
      parts.join(" ")
    end

    def format_data(data)
      return "" if data.blank?
      "- #{data.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")}"
    end

    def map_severity_to_level(severity)
      case severity
      when :fatal then 'fatal'
      when :error then 'error'
      when :warn then 'warning'
      else 'info'
      end
    end
  end
end
