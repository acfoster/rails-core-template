require 'rails_helper'

RSpec.describe Log, type: :model do
  include ActiveJob::TestHelper

  let(:user) { create(:user, email: "log_spec_#{SecureRandom.hex(4)}@example.com") }

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

  around do |example|
    with_env(
      "DB_LOGGING_ENABLED" => "true",
      "DB_LOG_ASYNC" => "false",
      "DB_LOG_TYPES" => Log::LOG_TYPES.join(","),
      "DB_LOG_LEVELS" => Log::LEVELS.join(","),
      "DB_LOG_MAX_BYTES" => "16000"
    ) do
      example.run
    end
  end

  before do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
  end

  describe 'associations' do
    it { should belong_to(:user).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:log_type) }
    it { should validate_presence_of(:level) }
    it { should validate_presence_of(:message) }
    it { should validate_presence_of(:occurred_at) }

    it { should validate_inclusion_of(:log_type).in_array(Log::LOG_TYPES) }
    it { should validate_inclusion_of(:level).in_array(Log::LEVELS) }
  end

  describe '.log crash protection' do
    it 'never raises even with invalid log_type' do
      expect {
        Log.log(
          log_type: 'invalid_type_not_in_enum',
          level: 'info',
          message: 'Test message'
        )
      }.not_to raise_error
    end

    it 'never raises even with invalid level' do
      expect {
        Log.log(
          log_type: 'error',
          level: 'invalid_level',
          message: 'Test message'
        )
      }.not_to raise_error
    end

    it 'normalizes invalid log_type to system' do
      log = Log.log(
        log_type: 'unknown_type',
        level: 'info',
        message: 'Test message'
      )
      
      expect(log.log_type).to eq('system')
    end

    it 'normalizes invalid level to info' do
      log = Log.log(
        log_type: 'error',
        level: 'unknown_level',
        message: 'Test message'
      )
      
      expect(log.level).to eq('info')
    end

    it 'accepts all valid log_types' do
      Log::LOG_TYPES.each do |valid_type|
        expect {
          Log.log(
            log_type: valid_type,
            level: 'info',
            message: "Test message for #{valid_type}"
          )
        }.not_to raise_error
      end
    end
  end

  describe 'scopes' do
    let!(:error_log) { create(:log, log_type: "error", level: "error", user: user) }
    let!(:info_log) { create(:log, log_type: "user_action", level: "info", user: user) }
    let!(:old_log) { create(:log, occurred_at: 2.days.ago, user: user) }

    describe '.recent' do
      it 'orders by occurred_at desc' do
        expect(Log.recent.first).to eq(info_log)
      end
    end

    describe '.by_type' do
      it 'filters by log_type' do
        expect(Log.by_type("error")).to include(error_log)
        expect(Log.by_type("error")).not_to include(info_log)
      end
    end

    describe '.by_level' do
      it 'filters by level' do
        expect(Log.by_level("error")).to include(error_log)
        expect(Log.by_level("error")).not_to include(info_log)
      end
    end

    describe '.by_user' do
      it 'filters by user_id' do
        expect(Log.by_user(user.id)).to include(error_log, info_log)
      end
    end

    describe '.errors' do
      it 'returns only error and fatal level logs' do
        expect(Log.errors).to include(error_log)
        expect(Log.errors).not_to include(info_log)
      end
    end

    describe '.warnings' do
      let!(:warning_log) { create(:log, level: "warning", user: user) }

      it 'returns only warning level logs' do
        expect(Log.warnings).to include(warning_log)
        expect(Log.warnings).not_to include(error_log, info_log)
      end
    end

    describe '.since' do
      it 'filters logs after given time' do
        expect(Log.since(1.day.ago)).to include(error_log, info_log)
        expect(Log.since(1.day.ago)).not_to include(old_log)
      end
    end

    describe '.by_action' do
      let!(:login_log) { create(:log, action: "user_login", user: user) }

      it 'searches action with ILIKE' do
        expect(Log.by_action("login")).to include(login_log)
        expect(Log.by_action("login")).not_to include(error_log)
      end
    end

    describe '.search_message' do
      let!(:specific_log) { create(:log, message: "Specific error message", user: user) }

      it 'searches message with ILIKE' do
        expect(Log.search_message("Specific")).to include(specific_log)
        expect(Log.search_message("Specific")).not_to include(error_log)
      end
    end
  end

  describe '.log' do
    it 'creates a log with all attributes' do
      log = Log.log(
        log_type: "http_request",
        level: "info",
        message: "GET /api/users",
        user: user,
        action: "index",
        controller: "api/users",
        request_id: "req_123",
        ip_address: "192.168.1.1",
        context: { method: "GET" },
        metadata: { duration_ms: 150 }
      )

      expect(log).to be_persisted
      expect(log.log_type).to eq("http_request")
      expect(log.level).to eq("info")
      expect(log.message).to eq("GET /api/users")
      expect(log.user).to eq(user)
      expect(log.context["method"]).to eq("GET")
      expect(log.metadata["duration_ms"]).to eq(150)
    end

    it 'sets occurred_at to current time' do
      travel_to Time.current do
        log = Log.log(
          log_type: "system",
          level: "info",
          message: "Test"
        )

        expect(log.occurred_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'handles creation failures gracefully' do
      allow(Log).to receive(:create!).and_raise(StandardError.new("DB Error"))
      expect(Rails.logger).to receive(:error).with(include("[LOG_MODEL_ERROR]"))

      Log.log(
        log_type: "error",
        level: "error",
        message: "Test"
      )
    end

    it 'enqueues async log writes when enabled' do
      with_env("DB_LOG_ASYNC" => "true", "DB_LOG_TYPES" => "error") do
        Log.log(
          log_type: "error",
          level: "error",
          message: "Async log",
          user_id: user.id
        )

        expect(enqueued_jobs.size).to eq(1)
        expect(enqueued_jobs.last[:job]).to eq(LogWriteJob)
        args = enqueued_jobs.last[:args].first
        expect(args["user_id"] || args[:user_id]).to eq(user.id)
        expect(args["log_type"] || args[:log_type]).to eq("error")
      end
    end

    it 'creates logs synchronously when async is disabled' do
      with_env("DB_LOG_ASYNC" => "false", "DB_LOG_TYPES" => "error") do
        expect {
          Log.log(
            log_type: "error",
            level: "error",
            message: "Sync log"
          )
        }.to change(Log, :count).by(1)
      end
    end

    it 'skips DB logging when disabled' do
      with_env("DB_LOGGING_ENABLED" => "false") do
        expect {
          Log.log(
            log_type: "error",
            level: "error",
            message: "Disabled"
          )
        }.not_to change(Log, :count)
      end
    end

    it 'honors DB_LOG_TYPES allowlist' do
      with_env("DB_LOG_TYPES" => "error") do
        expect {
          Log.log(
            log_type: "user_action",
            level: "info",
            message: "View list"
          )
        }.not_to change(Log, :count)
      end
    end

    it 'honors DB_LOG_LEVELS allowlist' do
      with_env("DB_LOG_LEVELS" => "error") do
        expect {
          Log.log(
            log_type: "error",
            level: "info",
            message: "Info level"
          )
        }.not_to change(Log, :count)
      end
    end

    it 'truncates oversized message and payloads' do
      with_env("DB_LOG_MAX_BYTES" => "20", "DB_LOG_TYPES" => "error") do
        log = Log.log(
          log_type: "error",
          level: "error",
          message: "a" * 100,
          context: { payload: "b" * 100 },
          metadata: { payload: "c" * 100 }
        )

        expect(log.message.bytesize).to be <= 20
        expect(log.context["truncated"]).to eq(true)
        expect(log.metadata["truncated"]).to eq(true)
      end
    end
  end

  describe '#level_badge_class' do
    it 'returns badge-danger for fatal' do
      log = build(:log, level: "fatal")
      expect(log.level_badge_class).to eq("badge-danger")
    end

    it 'returns badge-danger for error' do
      log = build(:log, level: "error")
      expect(log.level_badge_class).to eq("badge-danger")
    end

    it 'returns badge-warning for warning' do
      log = build(:log, level: "warning")
      expect(log.level_badge_class).to eq("badge-warning")
    end

    it 'returns badge-secondary for info' do
      log = build(:log, level: "info")
      expect(log.level_badge_class).to eq("badge-secondary")
    end
  end

  describe '#type_badge_class' do
    it 'returns badge-danger for error type' do
      log = build(:log, log_type: "error")
      expect(log.type_badge_class).to eq("badge-danger")
    end

    it 'returns badge-secondary for other types' do
      log = build(:log, log_type: "user_action")
      expect(log.type_badge_class).to eq("badge-secondary")
    end
  end
end
