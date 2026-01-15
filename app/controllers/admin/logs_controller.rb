class Admin::LogsController < Admin::BaseController

  def index
    @logs = Log.includes(:user)
               .recent
               .by_type(params[:log_type])
               .by_level(params[:level])
               .by_user(params[:user_id])
               .since(parse_since_param)

    if text_filters_enabled?
      @logs = @logs.by_action(params[:filter_action])
                   .by_controller(params[:filter_controller])
                   .search_message(params[:query])
    end

    # Advanced filtering (JSONB context) - disabled by default
    if context_filters_enabled?
      @logs = @logs.where(Arel.sql("context ->> 'error_type' = ?"), params[:error_type]) if params[:error_type].present?
    end

    if ip_filters_enabled? && params[:ip_address].present?
      @logs = @logs.where("ip_address = ?", params[:ip_address])
    end
    
    # Component filtering
    if context_filters_enabled? && params[:component].present?
      @logs = @logs.where(
        Arel.sql("context ->> 'component' = ? OR action ILIKE ?"), 
        params[:component], 
        "%#{params[:component]}%"
      )
    end
    
    # Date range filtering
    if params[:start_date].present?
      @logs = @logs.where('occurred_at >= ?', Date.parse(params[:start_date]).beginning_of_day)
    end
    
    if params[:end_date].present?
      @logs = @logs.where('occurred_at <= ?', Date.parse(params[:end_date]).end_of_day)
    end

    per_page = params[:per_page].to_i
    per_page = 50 if per_page <= 0
    per_page = [per_page, logs_per_page_max].min
    @logs = @logs.page(params[:page]).per(per_page)

    # For filter dropdowns
    @log_types = Log::LOG_TYPES
    @levels = Log::LEVELS
    @users = User.order(:email).pluck(:email, :id)
    if context_filters_enabled?
      @components = Log.where("context ->> 'component' IS NOT NULL")
                       .distinct
                       .pluck(Arel.sql("context ->> 'component'"))
                       .compact
                       .sort
      @error_types = Log.where(level: ['error', 'fatal'])
                        .where("context ->> 'error_type' IS NOT NULL")
                        .distinct
                        .pluck(Arel.sql("context ->> 'error_type'"))
                        .compact
                        .sort
    else
      @components = []
      @error_types = []
    end
    if text_filters_enabled?
      @controllers = Log.where.not(controller: nil)
                        .distinct
                        .limit(200)
                        .pluck(:controller)
                        .compact
                        .sort
      @actions = Log.where.not(action: nil)
                    .distinct
                    .pluck(:action)
                    .compact
                    .sort
                    .first(100)  # Limit to prevent UI overload
    else
      @controllers = []
      @actions = []
    end
  end

  def show
    @log = Log.includes(:user).find(params[:id])
  end
  
  def stats
    @stats = if stats_cache_enabled?
      Rails.cache.fetch("admin_logs_stats", expires_in: 60) { build_stats_payload }
    else
      build_stats_payload
    end
    
    respond_to do |format|
      format.html
      format.json { render json: @stats }
    end
  end
  
  def export
    @logs = Log.includes(:user)
               .where('occurred_at >= ?', 7.days.ago)
               .by_level(params[:level])
               .by_type(params[:log_type])
               .limit(log_export_max_rows)
    
    respond_to do |format|
      format.csv do
        headers['Content-Disposition'] = "attachment; filename=\"logs-#{Date.current}.csv\""
        headers['Content-Type'] ||= 'text/csv'
      end
      format.json { render json: @logs }
    end
  end

  private
  
  def build_stats_payload
    top_errors = []
    if context_filters_enabled?
      top_errors = Log.where(level: ['error', 'fatal'])
                      .where('occurred_at >= ?', 7.days.ago)
                      .group(Arel.sql("context ->> 'error_type'"))
                      .count
                      .sort_by { |k, v| -v }
                      .first(10)
    end

    {
      total_logs: Log.count,
      error_logs: Log.where(level: ['error', 'fatal']).count,
      warning_logs: Log.where(level: 'warning').count,
      logs_last_24h: Log.where('occurred_at >= ?', 24.hours.ago).count,
      unique_users_last_24h: Log.where('occurred_at >= ?', 24.hours.ago)
                                .where.not(user_id: nil)
                                .distinct
                                .count(:user_id),
      top_errors: top_errors,
      log_volume_by_hour: Log.where('occurred_at >= ?', 24.hours.ago)
                             .group_by_hour(:occurred_at)
                             .count
    }
  end

  def context_filters_enabled?
    env_bool("LOGS_CONTEXT_FILTERING_ENABLED", false)
  end

  def text_filters_enabled?
    env_bool("LOGS_TEXT_FILTERS_ENABLED", false)
  end

  def logs_per_page_max
    env_int("LOGS_PER_PAGE_MAX", 200)
  end

  def ip_filters_enabled?
    env_bool("LOGS_IP_FILTER_ENABLED", false)
  end

  def log_export_max_rows
    env_int("LOG_EXPORT_MAX_ROWS", 10_000)
  end

  def stats_cache_enabled?
    return false unless Rails.cache
    return false if Rails.cache.is_a?(ActiveSupport::Cache::NullStore)

    true
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

  def parse_since_param
    return nil if params[:since].blank?

    case params[:since]
    when '15m' then 15.minutes.ago
    when '1h' then 1.hour.ago
    when '6h' then 6.hours.ago
    when '24h' then 24.hours.ago
    when '3d' then 3.days.ago
    when '7d' then 7.days.ago
    when '30d' then 30.days.ago
    when 'custom'
      # Use start_date if provided
      params[:start_date].present? ? Date.parse(params[:start_date]).beginning_of_day : nil
    else 
      begin
        Time.parse(params[:since])
      rescue ArgumentError
        nil
      end
    end
  end
end
