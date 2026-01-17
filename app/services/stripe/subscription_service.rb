module Stripe
  class SubscriptionService
    PRICE_ID = ENV.fetch("STRIPE_PRICE_ID", "price_test_example")
    TRIAL_PERIOD_DAYS = 5

    def initialize(user)
      @user = user
      ::Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY")
    end

    def create_customer
      Rails.logger.info("[STRIPE] Creating customer for user_id: #{@user.id}")
      return @user.stripe_customer_id if @user.stripe_customer_id.present?

      ApplicationLogger.log_info(
        "Creating Stripe customer",
        category: "payments",
        data: { user_id: @user.id, email: @user.email },
        user: @user
      )

      customer = ::Stripe::Customer.create(
        email: @user.email,
        metadata: { user_id: @user.id }
      )

      @user.update!(stripe_customer_id: customer.id)
      Rails.logger.info("[STRIPE] Customer created successfully: #{customer.id} for user_id: #{@user.id}")
      
      ApplicationLogger.log_info(
        "Stripe customer created",
        category: "payments",
        data: { user_id: @user.id, stripe_customer_id: customer.id },
        user: @user
      )
      
      customer.id
    end

    def create_checkout_session(success_url:, cancel_url:)
      Rails.logger.info("[STRIPE] Creating checkout session for user_id: #{@user.id}")
      ApplicationLogger.log_info(
        "Stripe checkout session creation started",
        category: "payments",
        data: {
          user_id: @user.id,
          has_customer_id: @user.stripe_customer_id.present?,
          price_id: PRICE_ID,
          trial_days: TRIAL_PERIOD_DAYS
        },
        user: @user
      )
      
      customer_id = create_customer

      session = ::Stripe::Checkout::Session.create(
        customer: customer_id,
        mode: "subscription",
        payment_method_collection: "always", # Collect card upfront during trial
        line_items: [ {
          price: PRICE_ID,
          quantity: 1
        } ],
        success_url: success_url,
        cancel_url: cancel_url,
        subscription_data: {
          trial_period_days: TRIAL_PERIOD_DAYS,
          metadata: { user_id: @user.id }
        }
      )
      
      Rails.logger.info("[STRIPE] Checkout session created: #{session.id} for user_id: #{@user.id}")
      ApplicationLogger.log_info(
        "Stripe checkout session created",
        category: "payments",
        data: {
          user_id: @user.id,
          session_id: session.id,
          session_url: session.url
        },
        user: @user
      )
      
      session
    end

    def create_portal_session(return_url:)
      raise "User has no Stripe customer ID" unless @user.stripe_customer_id

      ::Stripe::BillingPortal::Session.create(
        customer: @user.stripe_customer_id,
        return_url: return_url
      )
    end

    def get_invoices(limit: 12)
      raise "User has no Stripe customer ID" unless @user.stripe_customer_id

      Rails.logger.info "Fetching invoices for user #{@user.id}, customer #{@user.stripe_customer_id}"

      ::Stripe::Invoice.list(
        customer: @user.stripe_customer_id,
        limit: limit
      )
    rescue ::Stripe::StripeError => e
      Rails.logger.error "Stripe API error fetching invoices: #{e.message}"
      Sentry.capture_exception(e, extra: { user_id: @user.id, stripe_customer_id: @user.stripe_customer_id })
      raise
    end

    def get_upcoming_invoice
      return nil unless @user.stripe_subscription_id

      Rails.logger.info "Fetching upcoming invoice for user #{@user.id}, subscription #{@user.stripe_subscription_id}"

      begin
        ::Stripe::Invoice.upcoming(
          subscription: @user.stripe_subscription_id
        )
      rescue ::Stripe::InvalidRequestError => e
        # No upcoming invoice (e.g., subscription canceled, trial period)
        Rails.logger.info "No upcoming invoice for user #{@user.id}: #{e.message}"
        nil
      rescue ::Stripe::StripeError => e
        Rails.logger.error "Stripe API error fetching upcoming invoice: #{e.message}"
        Sentry.capture_exception(e, extra: { user_id: @user.id, stripe_subscription_id: @user.stripe_subscription_id })
        nil
      end
    end

    def self.handle_webhook_event(event)
      # Set API key for webhook processing
      ::Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY")

      Rails.logger.info "[STRIPE] Processing Stripe webhook: #{event.type} (#{event.id})"
      ApplicationLogger.log_info(
        "Stripe webhook received",
        category: "payments",
        data: {
          event_type: event.type,
          event_id: event.id,
          livemode: event.livemode
        }
      )

      case event.type
      when "checkout.session.completed"
        handle_checkout_completed(event.data.object)
      when "customer.subscription.created"
        handle_subscription_created(event.data.object)
      when "customer.subscription.updated"
        handle_subscription_updated(event.data.object)
      when "customer.subscription.deleted"
        handle_subscription_deleted(event.data.object)
      when "invoice.payment_succeeded"
        handle_payment_succeeded(event.data.object)
      when "invoice.payment_failed"
        handle_payment_failed(event.data.object)
      else
        Rails.logger.info "Unhandled webhook event type: #{event.type}"
      end

      Rails.logger.info "Successfully processed webhook: #{event.type} (#{event.id})"
    rescue StandardError => e
      Rails.logger.error "Error processing webhook #{event.type} (#{event.id}): #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      Sentry.capture_exception(e, extra: { event_type: event.type, event_id: event.id, event_data: event.data.object.to_hash })
    end

    class << self
      private

      def handle_checkout_completed(session)
        # Checkout completed - store subscription ID and update status
        user = find_user_by_customer_id(session.customer)

        unless user
          Rails.logger.warn "Checkout completed for unknown customer: #{session.customer}"
          Log.log(
            log_type: 'error',
            level: 'warning',
            message: "Stripe checkout completed for unknown customer",
            action: 'stripe_checkout_unknown_customer',
            controller: 'stripe_service',
            context: {
              stripe_customer_id: session.customer,
              stripe_subscription_id: session.subscription
            }
          )
          return
        end

        Rails.logger.info "Checkout completed for user #{user.id}: subscription #{session.subscription}"
        Log.log(
          log_type: 'user_action',
          level: 'info',
          message: "Stripe checkout completed successfully",
          user: user,
          action: 'stripe_checkout_completed',
          controller: 'stripe_service',
          context: {
            stripe_subscription_id: session.subscription,
            subscription_status: 'trialing'
          }
        )

        user.update!(
          stripe_subscription_id: session.subscription,
          subscription_status: "trialing" # Checkout creates subscription in trialing status
        )
      end

      def handle_subscription_created(subscription)
        user = find_user_by_customer_id(subscription.customer)

        unless user
          Rails.logger.warn "Subscription created for unknown customer: #{subscription.customer}"
          Log.log(
            log_type: 'error',
            level: 'warning',
            message: "Stripe subscription created for unknown customer",
            action: 'stripe_subscription_unknown_customer',
            controller: 'stripe_service',
            context: {
              stripe_customer_id: subscription.customer,
              stripe_subscription_id: subscription.id,
              status: subscription.status
            }
          )
          return
        end

        Rails.logger.info "Subscription created for user #{user.id}: #{subscription.id} (status: #{subscription.status})"
        Log.log(
          log_type: 'user_action',
          level: 'info',
          message: "Stripe subscription created",
          user: user,
          action: 'stripe_subscription_created',
          controller: 'stripe_service',
          context: {
            stripe_subscription_id: subscription.id,
            subscription_status: subscription.status
          }
        )

        user.update!(
          stripe_subscription_id: subscription.id,
          subscription_status: subscription.status
        )
      end

      def handle_subscription_updated(subscription)
        user = find_user_by_customer_id(subscription.customer)

        unless user
          Rails.logger.warn "Subscription updated for unknown customer: #{subscription.customer}"
          Log.log(
            log_type: 'error',
            level: 'warning',
            message: "Stripe subscription updated for unknown customer",
            action: 'stripe_subscription_update_unknown_customer',
            controller: 'stripe_service',
            context: {
              stripe_customer_id: subscription.customer,
              stripe_subscription_id: subscription.id,
              status: subscription.status
            }
          )
          return
        end

        cancel_at = subscription.cancel_at ? Time.at(subscription.cancel_at) : nil

        Rails.logger.info "Subscription updated for user #{user.id}: #{subscription.id} (status: #{subscription.status}, cancel_at: #{cancel_at})"
        Log.log(
          log_type: 'user_action',
          level: 'info',
          message: "Stripe subscription updated",
          user: user,
          action: 'stripe_subscription_updated',
          controller: 'stripe_service',
          context: {
            stripe_subscription_id: subscription.id,
            subscription_status: subscription.status,
            subscription_cancel_at: cancel_at
          }
        )

        user.update!(
          subscription_status: subscription.status,
          subscription_cancel_at: cancel_at
        )
      end

      def handle_subscription_deleted(subscription)
        user = find_user_by_customer_id(subscription.customer)

        unless user
          Rails.logger.warn "Subscription deleted for unknown customer: #{subscription.customer}"
          Log.log(
            log_type: 'error',
            level: 'warning',
            message: "Stripe subscription deleted for unknown customer",
            action: 'stripe_subscription_delete_unknown_customer',
            controller: 'stripe_service',
            context: {
              stripe_customer_id: subscription.customer,
              stripe_subscription_id: subscription.id
            }
          )
          return
        end

        Rails.logger.info "Subscription deleted for user #{user.id}: #{subscription.id}"
        Log.log(
          log_type: 'user_action',
          level: 'warning',
          message: "Stripe subscription deleted/canceled",
          user: user,
          action: 'stripe_subscription_deleted',
          controller: 'stripe_service',
          context: {
            stripe_subscription_id: subscription.id,
            previous_status: user.subscription_status
          }
        )

        user.update!(
          subscription_status: "canceled",
          subscription_cancel_at: nil
        )
      end

      def handle_payment_succeeded(invoice)
        user = find_user_by_customer_id(invoice.customer)

        unless user
          Rails.logger.warn "Payment succeeded for unknown customer: #{invoice.customer}"
          Log.log(
            log_type: 'error',
            level: 'warning',
            message: "Stripe payment succeeded for unknown customer",
            action: 'stripe_payment_unknown_customer',
            controller: 'stripe_service',
            context: {
              stripe_customer_id: invoice.customer,
              invoice_id: invoice.id,
              amount_paid: invoice.amount_paid / 100.0
            }
          )
          return
        end

        Rails.logger.info "Payment succeeded for user #{user.id}: $#{invoice.amount_paid / 100.0} (invoice: #{invoice.id})"
        Log.log(
          log_type: 'user_action',
          level: 'info',
          message: "Stripe payment succeeded",
          user: user,
          action: 'stripe_payment_succeeded',
          controller: 'stripe_service',
          context: {
            invoice_id: invoice.id,
            amount_paid: invoice.amount_paid / 100.0,
            subscription_status: 'active'
          }
        )

        user.update!(
          subscription_status: "active"
        )
      end

      def handle_payment_failed(invoice)
        user = find_user_by_customer_id(invoice.customer)

        unless user
          Rails.logger.warn "Payment failed for unknown customer: #{invoice.customer}"
          Log.log(
            log_type: 'error',
            level: 'warning',
            message: "Stripe payment failed for unknown customer",
            action: 'stripe_payment_failed_unknown_customer',
            controller: 'stripe_service',
            context: {
              stripe_customer_id: invoice.customer,
              invoice_id: invoice.id,
              amount_due: invoice.amount_due / 100.0
            }
          )
          return
        end

        Rails.logger.error "Payment failed for user #{user.id}: $#{invoice.amount_due / 100.0} (invoice: #{invoice.id})"
        Log.log(
          log_type: 'error',
          level: 'error',
          message: "Stripe payment failed",
          user: user,
          action: 'stripe_payment_failed',
          controller: 'stripe_service',
          context: {
            invoice_id: invoice.id,
            amount_due: invoice.amount_due / 100.0,
            subscription_status: 'past_due'
          }
        )

        Sentry.capture_message(
          "Stripe payment failed",
          level: :warning,
          extra: {
            user_id: user.id,
            invoice_id: invoice.id,
            amount: invoice.amount_due / 100.0
          }
        )

        user.update!(
          subscription_status: "past_due"
        )
      end

      def find_user_by_customer_id(customer_id)
        User.find_by(stripe_customer_id: customer_id)
      end
    end
  end
end
