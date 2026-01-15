class CleanupOldLogsJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 1000

  def perform
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Rails.logger.info("[CLEANUP_LOGS] Starting cleanup of old logs...")

    total_deleted = 0
    per_type_deleted = {}

    Log::LOG_TYPES.each do |log_type|
      retention_days = LoggingConfig.log_retention_days_for(log_type)
      cutoff = retention_days.days.ago

      relation = Log.where(log_type: log_type).where('occurred_at < ?', cutoff)
      deleted_for_type = 0

      relation.in_batches(of: BATCH_SIZE) do |batch|
        deleted_for_type += batch.delete_all
      end

      if deleted_for_type.positive?
        per_type_deleted[log_type] = deleted_for_type
        total_deleted += deleted_for_type
      end
    end

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

    if total_deleted.zero?
      Rails.logger.info("[CLEANUP_LOGS] No old logs to clean up (duration_ms=#{duration_ms})")
      return
    end

    Rails.logger.info("[CLEANUP_LOGS] Deleted #{total_deleted} old logs in #{duration_ms}ms (per_type=#{per_type_deleted})")

    Log.log(
      log_type: 'background_job',
      level: 'info',
      message: 'Old logs cleanup completed',
      action: 'logs_cleanup_completed',
      context: {
        logs_deleted: total_deleted,
        per_type_deleted: per_type_deleted,
        retention_days_default: LoggingConfig.log_retention_days_default
      }
    )
  rescue StandardError => e
    Rails.logger.error("[CLEANUP_LOGS] Error during cleanup: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    Log.log(
      log_type: 'background_job',
      level: 'error',
      message: 'Old logs cleanup failed',
      action: 'logs_cleanup_failed',
      context: {
        error: e.message,
        error_class: e.class.name,
        backtrace: e.backtrace&.first(5)
      }
    )
  end
end
