class WebhooksController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :check_subscription
  skip_before_action :verify_authenticity_token
  allow_browser versions: :modern, block: false

  def stripe
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    endpoint_secret = ENV["STRIPE_WEBHOOK_SECRET"]

    Log.log(
      log_type: 'http_request',
      level: 'info',
      message: "Stripe webhook received",
      action: 'stripe_webhook_received',
      controller: 'webhooks',
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: {
        has_signature: sig_header.present?,
        payload_size: payload.bytesize
      }
    )

    begin
      event = ::Stripe::Webhook.construct_event(
        payload, sig_header, endpoint_secret
      )

      Log.log(
        log_type: 'http_request',
        level: 'info',
        message: "Stripe webhook verified",
        action: 'stripe_webhook_verified',
        controller: 'webhooks',
        request_id: request.request_id,
        ip_address: request.remote_ip,
        context: {
          event_type: event.type,
          event_id: event.id
        }
      )
    rescue JSON::ParserError => e
      Log.log(
        log_type: 'error',
        level: 'warning',
        message: "Stripe webhook invalid payload",
        action: 'stripe_webhook_invalid_payload',
        controller: 'webhooks',
        request_id: request.request_id,
        ip_address: request.remote_ip,
        context: {
          error: e.message
        }
      )
      render json: { error: "Invalid payload" }, status: 400
      return
    rescue ::Stripe::SignatureVerificationError => e
      Log.log(
        log_type: 'error',
        level: 'warning',
        message: "Stripe webhook signature verification failed",
        action: 'stripe_webhook_invalid_signature',
        controller: 'webhooks',
        request_id: request.request_id,
        ip_address: request.remote_ip,
        context: {
          error: e.message,
          has_signature: sig_header.present?
        }
      )
      render json: { error: "Invalid signature" }, status: 400
      return
    end

    # Handle the event
    Stripe::SubscriptionService.handle_webhook_event(event)

    Log.log(
      log_type: 'http_request',
      level: 'info',
      message: "Stripe webhook processed successfully",
      action: 'stripe_webhook_processed',
      controller: 'webhooks',
      request_id: request.request_id,
      ip_address: request.remote_ip,
      context: {
        event_type: event.type,
        event_id: event.id
      }
    )

    render json: { status: "success" }, status: 200
  end
end
