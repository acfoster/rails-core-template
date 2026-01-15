class LogWriteJob < ApplicationJob
  queue_as :low_priority

  def perform(attrs)
    Log.without_async do
      Log.create!(attrs)
    end
  rescue StandardError => e
    Rails.logger.error("[LOG_WRITE_JOB] Failed to persist log: #{e.class} - #{e.message}")
  end
end
