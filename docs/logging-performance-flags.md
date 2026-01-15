# Logging Performance Flags

This app persists selected logs to the database for audit and debugging, while
keeping page views and low-value logs out of the request path. The Log model
now supports async writes through Solid Queue to reduce request latency.

## What goes to the DB vs Rails.logger
- DB (default allowlist): error, http_error, server_error, client_error, warning,
  virus_scan, subscription, authentication, authorization, background_job
- Rails.logger: user_action/info style page views and anything filtered out by allowlists

## Recommended Railway ENV values
DB_LOGGING_ENABLED=true
DB_LOG_ASYNC=true
DB_LOG_TYPES=error,http_error,server_error,client_error,warning,virus_scan,subscription,authentication,authorization,background_job
DB_LOG_LEVELS=warning,error,fatal
DB_LOG_MAX_BYTES=16000
REQUEST_DB_LOGGING_ENABLED=false
REQUEST_LOG_SLOW_THRESHOLD_MS=800
LOG_RETENTION_DAYS_DEFAULT=30
LOG_RETENTION_DAYS_ERROR=90
LOG_RETENTION_DAYS_HTTP_ERROR=90
LOG_RETENTION_DAYS_USER_ACTION=7

## Solid Queue worker
- Web process: `bundle exec rails server -p $PORT -b 0.0.0.0`
- Worker process: `bundle exec rails solid_queue:start`
- Queue names: default (most jobs), low_priority (LogWriteJob)
- Ensure Railway has a dedicated worker service always on.

## Retention cleanup
- CleanupOldLogsJob deletes logs by type using LOG_RETENTION_DAYS_* values.
- Runs daily via `config/recurring.yml`.
