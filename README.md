# Core App Template

A production-ready Rails 8 template with Devise authentication, Stripe billing, Resend email, Solid Queue background jobs, VirusScan integration, and Railway-ready deployment.

## Starting a new project from this template

Option 1: Clone then run the generator

```bash
git clone <repo-url> my_app
cd my_app
bin/new_project
bin/verify
```

Option 2: GitHub template flow

1) Click "Use this template" on GitHub to create a new repo.
2) Clone your new repo locally.
3) Run `bin/new_project` to rebrand/rename and `bin/verify` to validate.

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
bin/install-git-hooks
bin/rails db:create db:migrate db:seed
bin/rails s
```

## Environment variables

Copy the template env file and adjust as needed:

```bash
cp .env.example .env
```

For local development you can leave Stripe, Resend, and virus scanning values blank unless you are testing those integrations.
Use `bin/verify` as the recommended way to validate your setup.

## Seeded credentials (development only)

The seed data creates an admin and a test user for local development. These are created automatically by `bin/new_project` and can be customized in `db/seeds.rb`.

Admin:
- Email: admin@example.com
- Password: Password123!

Test user:
- Email: test@example.com
- Password: Password123!

## 🎨 Branding & Theme Customization

Logo: `app/assets/images/logo.svg`  
Favicons: `app/assets/images/favicon*.png` and `app/assets/images/favicon.ico`  
Colors: `app/assets/stylesheets/theme.css`

Update the CSS variables in `app/assets/stylesheets/theme.css` to change the theme across the app.

## Important: Ruby version

This template requires Ruby >= 3.2 and Bundler 4. If your shell picks up system Ruby (2.6),
Bundler will fail. Use the bin wrappers to ensure the correct Ruby is loaded.

Recommended commands:

```bash
bin/bootstrap
bin/verify
bin/rspec
bin/test
```

## Git hooks

Install the local git hooks once per clone to block pushes when lint/tests fail:

```bash
bin/install-git-hooks
```

## Tests

```bash
bin/rspec
bin/test
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
