# Deployment Checklist

Use this checklist for production releases.

## Pre-Deploy
- `bin/bootstrap`
- `bundle exec rails zeitwerk:check`
- `bundle exec rspec`
- `bundle exec rails test`
- Confirm ENV vars are set in Railway
- Confirm Stripe webhook points to `/webhooks/stripe`

## Deploy
- Push the branch/tag to your deploy target
- Verify Railway build and release logs

## Post-Deploy
- Visit `/up` health check
- Verify sign-in and dashboard access
- Trigger a Stripe test webhook event
- Confirm background worker is running
