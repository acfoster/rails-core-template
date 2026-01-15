# Core App Template Setup

## Table of Contents
1. Local Development Setup
2. Environment Configuration
3. Database Setup
4. Running the Application
5. Running Tests

---

## Local Development Setup

### Prerequisites

- Ruby 3.3.0 (see `.ruby-version`)
- Rails 8.0.4
- PostgreSQL 14+
- Node.js 18+ (for assets)

### Install Dependencies

```bash
bin/bootstrap
```

`bin/bootstrap` installs the Bundler version from `Gemfile.lock`, runs `bundle install`, and verifies Rails.

---

## Environment Configuration

Copy `.env.example` to `.env` and update values for your local setup:

```bash
cp .env.example .env
```

Common env vars:

```bash
# Database
DATABASE_URL=postgresql://localhost/core_app_template_development

# Stripe
STRIPE_SECRET_KEY=sk_test_YOUR_KEY
STRIPE_WEBHOOK_SECRET=whsec_YOUR_SECRET
STRIPE_PRICE_ID=price_YOUR_PRICE_ID

# Resend (email)
RESEND_API_KEY=re_YOUR_KEY
DEFAULT_FROM_EMAIL=hello@example.com

# Virus scanning (optional)
CLOUDMERSIVE_API_KEY=YOUR_KEY
ENABLE_VIRUS_SCAN=true

# Sentry (optional)
SENTRY_DSN=
```

---

## Database Setup

```bash
bin/rails db:create
bin/rails db:migrate
```

---

## Running the Application

```bash
bin/rails s
```

---

## Running Tests

```bash
bundle exec rspec
bundle exec rails test
```
