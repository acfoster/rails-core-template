# Production Setup (Railway)

This guide covers production configuration for the Core App Template on Railway.

## Required Services
- Web service (Rails)
- Worker service (Solid Queue)
- Postgres

## Required Environment Variables

```bash
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true
SECRET_KEY_BASE=...
DATABASE_URL=...

# Stripe
STRIPE_SECRET_KEY=...
STRIPE_WEBHOOK_SECRET=...
STRIPE_PRICE_ID=...

# Resend
RESEND_API_KEY=...
DEFAULT_FROM_EMAIL=hello@example.com

# Virus scanning (optional)
CLOUDMERSIVE_API_KEY=...
ENABLE_VIRUS_SCAN=true

# Logging
DB_LOGGING_ENABLED=true
DB_LOG_ASYNC=true
DB_LOG_TYPES=error,http_error,server_error,client_error,warning,virus_scan,subscription,authentication,authorization,background_job
DB_LOG_LEVELS=warning,error,fatal
```

## Railway Service Commands

### Web
```bash
bundle exec rails server -p $PORT -b 0.0.0.0
```

### Worker
```bash
bundle exec rails solid_queue:start
```

## Stripe Webhooks

Configure a Stripe webhook to point at:

```
POST /webhooks/stripe
```

## Health Check

Railway can use:

```
GET /up
```
