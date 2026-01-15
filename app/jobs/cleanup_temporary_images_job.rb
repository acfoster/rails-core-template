class CleanupTemporaryImagesJob < ApplicationJob
  queue_as :default

  # This job ensures that temporary uploaded images are deleted even if:
  # - The request fails after upload
  # - The AI processing errors
  # - Validation fails after upload
  # - The cleanup wasn't triggered for any reason

  def perform
    Rails.logger.info("[CLEANUP_JOB] Enqueued CleanupTemporaryImagesJob")
    Rails.logger.info("[CLEANUP_JOB] Starting temporary image cleanup...")

    deleted_count = TemporaryImageStorage.cleanup_expired!

    Rails.logger.info("[CLEANUP_JOB] Cleanup complete - deleted #{deleted_count} files")
  rescue StandardError => e
    Rails.logger.error("[CLEANUP_JOB] Cleanup failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    # Don't re-raise - we'll try again on next scheduled run
  end
end
