class UsersController < ApplicationController
  before_action :authenticate_user!

  def profile
    @user = current_user
    @active_tab = "overview"
    Log.log(
      log_type: 'user_action',
      level: 'info',
      message: "Viewed profile page",
      user: current_user,
      action: 'view_profile',
      controller: 'users',
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: { tab: 'overview' }
    )
  end

  def account
    @user = current_user
    @active_tab = "account"
    Log.log(
      log_type: 'user_action',
      level: 'info',
      message: "Viewed account page",
      user: current_user,
      action: 'view_account',
      controller: 'users',
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: { tab: 'account' }
    )
  end

  def payment
    @user = current_user
    @active_tab = "payment"
    Log.log(
      log_type: 'user_action',
      level: 'info',
      message: "Viewed payment page",
      user: current_user,
      action: 'view_payment',
      controller: 'users',
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: { tab: 'payment' }
    )
  end

  def billing
    @user = current_user
    @active_tab = "billing"
    @invoices = []
    @upcoming_invoice = nil

    Log.log(
      log_type: 'user_action',
      level: 'info',
      message: "Viewed billing page",
      user: current_user,
      action: 'view_billing',
      controller: 'users',
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: { tab: 'billing' }
    )

    if @user.stripe_customer_id.present?
      service = Stripe::SubscriptionService.new(@user)

      begin
        @invoices = service.get_invoices.data
      rescue StandardError => e
        Rails.logger.error "Failed to fetch invoices for user #{@user.id}: #{e.message}"
        Sentry.capture_exception(e, extra: { user_id: @user.id, stripe_customer_id: @user.stripe_customer_id })
      end

      begin
        @upcoming_invoice = service.get_upcoming_invoice
      rescue StandardError => e
        Rails.logger.error "Failed to fetch upcoming invoice for user #{@user.id}: #{e.message}"
        Sentry.capture_exception(e, extra: { user_id: @user.id, stripe_subscription_id: @user.stripe_subscription_id })
      end
    end
  end
end
