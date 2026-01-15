# Core App Template

A production-ready Rails 8 template with Devise authentication, Stripe billing, Resend email, Solid Queue background jobs, VirusScan integration, and Railway-ready deployment.

## What This Template Includes
- Devise auth (registrations, sessions, confirmations, password reset)
- Dashboard shell + `dashboard_poll` stub endpoint
- Admin namespace (dashboard, users, logs, financials)
- Stripe (checkout + webhooks)
- Logging and auditing
- Resend email
- ActiveJob + Solid Queue
- Virus scanning for uploads (Cloudmersive/ClamAV)
- Railway + Docker configuration
- `bin/bootstrap` (rbenv-aware)

## Local Setup

- Ensure rbenv/asdf uses the version in `.ruby-version`.

```bash
bin/bootstrap
bin/rails db:create db:migrate db:seed
bin/rails s
```

## Tests

```bash
bundle exec rspec
bundle exec rails test
```

## Deploy to Railway

- Use `railway.json` and the Dockerfile as-is
- Required ENV vars:
  - `RAILS_ENV`, `RAILS_LOG_TO_STDOUT`, `RAILS_SERVE_STATIC_FILES`, `SECRET_KEY_BASE`, `DATABASE_URL`
  - `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_ID`
  - `RESEND_API_KEY`, `DEFAULT_FROM_EMAIL`
  - `CLOUDMERSIVE_API_KEY`, `ENABLE_VIRUS_SCAN`
  - `DB_LOGGING_ENABLED`, `DB_LOG_ASYNC`, `DB_LOG_TYPES`, `DB_LOG_LEVELS`
- Run migrations during deploy: `bundle exec rails db:migrate`
- Configure Stripe webhook to `POST /webhooks/stripe`

## Where To Add A New Feature Module

1. Place feature code under `app/features/` or `app/domains/`.
2. Keep shared/core code in `app/controllers`, `app/models`, `app/services`.
3. Add routes under `authenticate :user do` in `config/routes.rb`.
4. Add request specs under `spec/requests/` and unit specs under `spec/models/`.

## Documentation

- `docs/SETUP.md`
- `docs/PRODUCTION_SETUP.md`
- `docs/logging-performance-flags.md`
- `docs/uploads-and-scanning.md`
- `DEPLOYMENT.md`
- Domain-specific docs (if any) are archived in `docs/archive`.
