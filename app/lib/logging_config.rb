module LoggingConfig
  DEFAULT_DB_LOG_TYPES = %w[
    error
    http_error
    server_error
    client_error
    warning
    virus_scan
    subscription
    authentication
    authorization
    background_job
  ].freeze
  DEFAULT_DB_LOG_MAX_BYTES = 16_000

  def self.db_logging_enabled?
    env_bool("DB_LOGGING_ENABLED", true)
  end

  def self.db_log_async?
    env_bool("DB_LOG_ASYNC", true)
  end

  def self.db_log_types
    env_list("DB_LOG_TYPES") || DEFAULT_DB_LOG_TYPES
  end

  def self.db_log_levels
    env_list("DB_LOG_LEVELS")
  end

  def self.db_log_max_bytes
    value = ENV["DB_LOG_MAX_BYTES"]
    return DEFAULT_DB_LOG_MAX_BYTES if value.nil? || value.strip.empty?

    value.to_i
  end

  def self.log_retention_days_default
    value = ENV["LOG_RETENTION_DAYS_DEFAULT"]
    return 30 if value.nil? || value.strip.empty?

    value.to_i
  end

  def self.log_retention_days_for(log_type)
    key = "LOG_RETENTION_DAYS_#{log_type.to_s.upcase}"
    value = ENV[key]
    return log_retention_days_default if value.nil? || value.strip.empty?

    value.to_i
  end

  def self.env_list(key)
    value = ENV[key]
    return nil if value.nil?

    list = value.split(",").map(&:strip).reject(&:empty?)
    list.empty? ? nil : list
  end

  def self.env_bool(key, default)
    value = ENV[key]
    return default if value.nil?

    normalized = value.to_s.strip.downcase
    return false if %w[false 0 no n].include?(normalized)
    return true if %w[true 1 yes y].include?(normalized)

    default
  end
end
