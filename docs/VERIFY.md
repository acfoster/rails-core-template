# Verification Checklist

Run these commands after major changes:

```bash
bin/bootstrap
bundle exec rails db:drop db:create db:migrate db:seed
bundle exec rails zeitwerk:check
bundle exec rspec
bundle exec rails test
```

Manual smoke checks:
- Start server: `bundle exec rails s`
- Visit `/`
- Sign in and land on `/dashboard`
- Visit `/dashboard_poll` and confirm JSON response
- Visit `/admin` as an admin user
- Hit Stripe webhook endpoint: `POST /webhooks/stripe` (test event)
