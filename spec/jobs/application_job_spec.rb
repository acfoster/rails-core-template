require 'rails_helper'

RSpec.describe ApplicationJob, type: :job do
  include ActiveJob::TestHelper

  class SpecDummyJob < ApplicationJob
    def perform
      true
    end
  end

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

  it 'logs background job start and completion for normal jobs' do
    with_env(
      "DB_LOGGING_ENABLED" => "true",
      "DB_LOG_ASYNC" => "false",
      "DB_LOG_TYPES" => Log::LOG_TYPES.join(","),
      "DB_LOG_LEVELS" => Log::LEVELS.join(",")
    ) do
      expect(ApplicationLogger).to receive(:log_info).twice.and_call_original
      SpecDummyJob.perform_now
    end
  end

  it 'does not log background job start or completion for LogWriteJob' do
    with_env(
      "DB_LOGGING_ENABLED" => "true",
      "DB_LOG_ASYNC" => "false",
      "DB_LOG_TYPES" => Log::LOG_TYPES.join(","),
      "DB_LOG_LEVELS" => Log::LEVELS.join(",")
    ) do
      expect(ApplicationLogger).not_to receive(:log_info)
      LogWriteJob.perform_now(
        log_type: "system",
        level: "info",
        message: "Log write test",
        occurred_at: Time.current
      )
    end
  end
end
