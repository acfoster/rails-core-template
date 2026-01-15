# Schedule automatic cleanup of temporary uploaded images
# Runs every 15 minutes to ensure orphaned files are removed

Rails.application.config.after_initialize do
  # Only schedule in server mode (not console, rake tasks, etc.)
  if defined?(Rails::Server)
    # Use a simple approach with a recurring job
    # In production, consider using a proper scheduler like sidekiq-scheduler or whenever gem

    Thread.new do
      loop do
        sleep 15.minutes

        begin
          CleanupTemporaryImagesJob.perform_later
        rescue StandardError => e
          Rails.logger.error("[CLEANUP_SCHEDULER] Failed to enqueue cleanup job: #{e.message}")
        end
      end
    end
  end
end
