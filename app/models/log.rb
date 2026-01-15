class Log < ApplicationRecord
  belongs_to :user, optional: true

  # Log types
  LOG_TYPES = %w[
    http_request
    http_error
    user_action
    error
    virus_scan
    database_query
    system
    authentication
    authorization
    background_job
    client_error
    server_error
    warning
    subscription
    cleanup
  ].freeze

  # Log levels
  LEVELS = %w[debug info warning error fatal].freeze

  validates :log_type, presence: true, inclusion: { in: LOG_TYPES }
  validates :level, presence: true, inclusion: { in: LEVELS }
  validates :message, presence: true
  validates :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc) }
  scope :by_type, ->(type) { where(log_type: type) if type.present? }
  scope :by_level, ->(level) { where(level: level) if level.present? }
  scope :by_user, ->(user_id) { where(user_id: user_id) if user_id.present? }
  scope :by_action, ->(action) { where("action ILIKE ?", "%#{action}%") if action.present? }
  scope :by_controller, ->(controller) { where(controller: controller) if controller.present? }
  scope :search_message, ->(query) { where("message ILIKE ?", "%#{query}%") if query.present? }
  scope :errors, -> { where(level: %w[error fatal]) }
  scope :warnings, -> { where(level: 'warning') }
  scope :since, ->(time) { where('occurred_at >= ?', time) if time.present? }

  def self.log(log_type:, level:, message:, user: nil, user_id: nil, action: nil, controller: nil, request_id: nil, ip_address: nil, context: {}, metadata: {})
    normalized_log_type = LOG_TYPES.include?(log_type.to_s) ? log_type.to_s : 'system'
    normalized_level = LEVELS.include?(level.to_s) ? level.to_s : 'info'

    max_bytes = LoggingConfig.db_log_max_bytes
    resolved_user_id = user_id || user&.id
    sanitized_message = truncate_string(message.to_s, max_bytes)
    sanitized_context = sanitize_payload(context, max_bytes)
    sanitized_metadata = sanitize_payload(metadata, max_bytes)

    attrs = {
      log_type: normalized_log_type,
      level: normalized_level,
      message: sanitized_message.presence || "Log message missing",
      user_id: resolved_user_id,
      action: action,
      controller: controller,
      request_id: request_id,
      ip_address: ip_address,
      context: sanitized_context,
      metadata: sanitized_metadata,
      occurred_at: Time.current
    }

    unless LoggingConfig.db_logging_enabled?
      emit_to_rails_logger(attrs) if %w[warning error fatal].include?(normalized_level)
      return nil
    end

    unless db_log_allowed?(normalized_log_type, normalized_level)
      emit_to_rails_logger(attrs)
      return nil
    end

    if LoggingConfig.db_log_async?
      begin
        LogWriteJob.perform_later(attrs)
        return Log.new(attrs)
      rescue StandardError => e
        Rails.logger.error("[LOG_MODEL_ERROR] Failed to enqueue log job: #{e.class} - #{e.message}")
        return nil
      end
    end

    create!(attrs)
  rescue StandardError => e
    # Fallback to Rails logger if database logging fails
    Rails.logger.error("[LOG_MODEL_ERROR] Failed to create log: #{e.message}")
    Sentry.capture_exception(e, extra: {
      log_type: log_type,
      level: level,
      message: sanitized_message,
      user_id: resolved_user_id,
      action: action,
      controller: controller,
      request_id: request_id,
      ip_address: ip_address,
      context: sanitized_context,
      metadata: sanitized_metadata
    })
    nil
  end

  def self.db_log_allowed?(log_type, level)
    allowed_types = LoggingConfig.db_log_types
    allowed_levels = LoggingConfig.db_log_levels

    return false if allowed_types && !allowed_types.include?(log_type)
    return false if allowed_levels && !allowed_levels.include?(level)

    true
  end
  private_class_method :db_log_allowed?

  def self.emit_to_rails_logger(attrs)
    level = attrs[:level]
    log_method = case level
                 when 'debug' then :debug
                 when 'warning' then :warn
                 when 'error' then :error
                 when 'fatal' then :fatal
                 else :info
                 end

    payload = {
      log_type: attrs[:log_type],
      level: attrs[:level],
      message: attrs[:message],
      user_id: attrs[:user_id],
      action: attrs[:action],
      controller: attrs[:controller],
      request_id: attrs[:request_id],
      ip_address: attrs[:ip_address],
      context: attrs[:context],
      metadata: attrs[:metadata]
    }

    Rails.logger.public_send(log_method, payload.to_json)
  rescue StandardError
    Rails.logger.info("[LOG_MODEL_ERROR] Failed to emit Rails logger payload")
  end
  private_class_method :emit_to_rails_logger

  def self.sanitize_payload(payload, max_bytes)
    return {} if payload.nil?

    if payload.is_a?(Hash) || payload.is_a?(Array)
      json = JSON.generate(payload)
      return payload if json.bytesize <= max_bytes

      preview = truncate_string(json, max_bytes)
      return {
        "truncated" => true,
        "bytesize" => json.bytesize,
        "preview" => preview
      }
    end

    truncate_string(payload.to_s, max_bytes)
  rescue StandardError
    { "truncated" => true, "preview" => truncate_string(payload.to_s, max_bytes) }
  end
  private_class_method :sanitize_payload

  def self.truncate_string(value, max_bytes)
    normalized = value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    return normalized if normalized.bytesize <= max_bytes

    truncated = normalized.byteslice(0, max_bytes)
    truncated.force_encoding("UTF-8").scrub
  end
  private_class_method :truncate_string

  def level_badge_class
    case level
    when 'fatal', 'error' then 'badge-danger'
    when 'warning' then 'badge-warning'
    when 'info' then 'badge-secondary'
    else 'badge-secondary'
    end
  end

  def type_badge_class
    case log_type
    when 'error' then 'badge-danger'
    when 'user_action' then 'badge-secondary'
    when 'http_request' then 'badge-secondary'
    when 'background_job' then 'badge-info'
    else 'badge-secondary'
    end
  end
end
