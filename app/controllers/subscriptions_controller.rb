class SubscriptionsController < ApplicationController
  skip_before_action :check_subscription
  before_action :require_confirmed_email, only: [:create, :portal]

  def new
    # Show subscription page if trial expired
  end

  def create
    Rails.logger.info "Creating checkout session for user #{current_user.id}"
    Log.log(
      log_type: 'user_action',
      level: 'info',
      message: "Subscription checkout initiated",
      user: current_user,
      action: 'subscription_checkout_initiated',
      controller: 'subscriptions',
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: {
        has_stripe_customer: current_user.stripe_customer_id.present?,
        trial_status: current_user.on_trial? ? 'active' : 'expired'
      }
    )

    service = Stripe::SubscriptionService.new(current_user)

    session = service.create_checkout_session(
      success_url: dashboard_url,
      cancel_url: new_subscription_url
    )

    Rails.logger.info "Redirecting user #{current_user.id} to Stripe Checkout: #{session.url}"
    Log.log(
      log_type: 'user_action',
      level: 'info',
      message: "Redirecting to Stripe checkout",
      user: current_user,
      action: 'stripe_checkout_redirect',
      controller: 'subscriptions',
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: {
        stripe_session_id: session.id,
        stripe_customer_id: current_user.stripe_customer_id
      }
    )
    redirect_to session.url, allow_other_host: true
  rescue StandardError => e
    Rails.logger.error "Failed to create checkout session for user #{current_user.id}: #{e.message}"
    Log.log(
      log_type: 'error',
      level: 'error',
      message: "Failed to create Stripe checkout session",
      user: current_user,
      action: 'subscription_checkout_failed',
      controller: 'subscriptions',
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: {
        error: e.message,
        error_class: e.class.name
      }
    )
    Sentry.capture_exception(e, extra: { user_id: current_user.id })
    redirect_to new_subscription_path, alert: "Unable to start checkout. Please try again or contact support."
  end

  def portal
    Rails.logger.info "Creating billing portal session for user #{current_user.id}"
    Log.log(
      log_type: 'user_action',
      level: 'info',
      message: "Billing portal access initiated",
      user: current_user,
      action: 'billing_portal_initiated',
      controller: 'subscriptions',
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: {
        stripe_customer_id: current_user.stripe_customer_id,
        subscription_status: current_user.subscription_status
      }
    )

    service = Stripe::SubscriptionService.new(current_user)

    session = service.create_portal_session(
      return_url: profile_payment_url
    )

    Rails.logger.info "Redirecting user #{current_user.id} to Stripe Billing Portal: #{session.url}"
    Log.log(
      log_type: 'user_action',
      level: 'info',
      message: "Redirecting to Stripe billing portal",
      user: current_user,
      action: 'stripe_portal_redirect',
      controller: 'subscriptions',
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: {
        stripe_session_id: session.id,
        stripe_customer_id: current_user.stripe_customer_id
      }
    )
    redirect_to session.url, allow_other_host: true
  rescue StandardError => e
    Rails.logger.error "Failed to create billing portal session for user #{current_user.id}: #{e.message}"
    Log.log(
      log_type: 'error',
      level: 'error',
      message: "Failed to create Stripe billing portal session",
      user: current_user,
      action: 'billing_portal_failed',
      controller: 'subscriptions',
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: {
        error: e.message,
        error_class: e.class.name,
        stripe_customer_id: current_user.stripe_customer_id
      }
    )
    Sentry.capture_exception(e, extra: { user_id: current_user.id, stripe_customer_id: current_user.stripe_customer_id })
    redirect_to profile_payment_path, alert: "Unable to access billing portal. Please try again or contact support."
  end

  private

  def require_confirmed_email
    return if current_user.confirmed?

    Log.log(
      log_type: 'user_action',
      level: 'info',
      message: "Blocked subscription action: email not confirmed",
      action: 'subscription_blocked_unconfirmed_email',
      controller: 'subscriptions',
      request_id: request.request_id,
      ip_address: request.remote_ip,
      user: current_user,
      context: {
        email: current_user.email
      }
    )

    redirect_to new_user_confirmation_path, alert: "Please confirm your email before continuing. You can resend the confirmation email here."
  end
end
