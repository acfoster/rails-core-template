# Async DB Logging Setup Instructions

## Overview
This branch implements asynchronous database logging using ActiveJob + Solid Queue to improve performance and reduce request blocking.

## Local Development Setup

### Prerequisites
- Ruby 3.3.0 (as specified in .ruby-version) 
- Bundler 4.0.3 (required by Gemfile.lock)

### Installation Steps

1. **Install correct bundler version:**
   ```bash
   gem install bundler -v 4.0.3
   ```

2. **Install dependencies:**
   ```bash
   bundle install
   ```

3. **Run database migrations:**
   ```bash
   bin/rails db:migrate
   ```

4. **Run tests:**
   ```bash
   bundle exec rspec
   ```

### Running with Solid Queue Worker (Development)

To test async logging locally, start the Solid Queue worker:

```bash
# In a separate terminal
bundle exec rails solid_queue:start
```

This will process jobs from all queues including `low_priority` queue used by `LogWriteJob`.

### Environment Configuration

The async logging can be controlled via environment variables:

- `DB_LOGGING_ENABLED=true/false` - Enable/disable database logging (default: true)
- `DB_LOG_ASYNC=true/false` - Use async job queue vs synchronous (default: true) 
- `DB_LOG_TYPES` - Comma-separated allowlist of log types (default: see LoggingConfig::DEFAULT_DB_LOG_TYPES)
- `DB_LOG_MAX_BYTES=16000` - Maximum size for log payloads (default: 16000)

## Production Deployment (Railway)

### Procfile Configuration
The Procfile is correctly configured for Railway:
```
web: bundle exec rails server -p $PORT -b 0.0.0.0  
worker: bundle exec rails solid_queue:start
```

### Docker Build
The Dockerfile has been updated to install bundler 4.0.3:
```dockerfile
RUN gem install bundler -v 4.0.3 && bundle install
```

### Environment Variables
Production environment automatically uses `config.active_job.queue_adapter = :solid_queue`

## Testing

### Core Logging Tests
```bash
bundle exec rspec spec/models/log_spec.rb
```

## Key Files Modified

- `app/jobs/log_write_job.rb` - Async logging job
- `app/jobs/cleanup_old_logs_job.rb` - Log retention cleanup  
- `app/lib/logging_config.rb` - Configuration and environment flags
- `app/models/log.rb` - Updated Log.log method for async support
- `config/queue.yml` - Solid Queue configuration
- `Dockerfile` - Bundler 4.0.3 installation
- `db/migrate/20260111140000_add_indexes_to_logs.rb` - Performance indexes

## Safety Features

1. **Graceful Fallback**: If async job fails, logs are written to Rails.logger
2. **Size Caps**: Log payloads are truncated to prevent memory issues
3. **Allowlist**: Only specified log types are persisted to database
4. **Retention**: Configurable cleanup of old logs by type
5. **No Request Crashes**: Log.log never raises exceptions

## Worker Command

For Railway deployment, the worker is configured to process all queues (`"*"`), ensuring the `low_priority` queue used by LogWriteJob is processed correctly.
