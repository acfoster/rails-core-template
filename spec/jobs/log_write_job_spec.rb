require 'rails_helper'

RSpec.describe LogWriteJob, type: :job do
  include ActiveJob::TestHelper

  def with_env(vars)
    original = {}
    vars.each do |key, value|
      original[key] = ENV[key]
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
    yield
  ensure
    original.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end

  before do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
  end

  it 'does not enqueue another LogWriteJob while running' do
    with_env(
      "DB_LOGGING_ENABLED" => "true",
      "DB_LOG_ASYNC" => "true",
      "DB_LOG_TYPES" => Log::LOG_TYPES.join(","),
      "DB_LOG_LEVELS" => Log::LEVELS.join(",")
    ) do
      described_class.perform_now(
        log_type: "system",
        level: "info",
        message: "Log write test",
        occurred_at: Time.current
      )

      expect(enqueued_jobs).to be_empty
    end
  end
end
