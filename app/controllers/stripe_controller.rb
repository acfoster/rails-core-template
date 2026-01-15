class StripeController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:webhook]
  before_action :authenticate_user!, except: [:webhook]

  def create_checkout_session
    price_id = params[:price_id]
    user_id = params[:user_id]
    
    user = User.find(user_id)
    service = StripeService.new(user)
    
    begin
      session = Stripe::Checkout::Session.create({
        payment_method_types: ['card'],
        line_items: [{
          price: price_id,
          quantity: 1,
        }],
        mode: 'subscription',
        success_url: "#{request.base_url}/dashboard?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "#{request.base_url}/dashboard",
        client_reference_id: user_id,
        customer_email: user.email,
      })

      render json: { url: session.url }
    rescue Stripe::StripeError => e
      render json: { error: e.message }, status: 422
    end
  end

  def webhook
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = ENV['STRIPE_WEBHOOK_SECRET']

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
    rescue JSON::ParserError, Stripe::SignatureVerificationError => e
      render json: { error: 'Invalid payload or signature' }, status: :bad_request
      return
    end

    case event['type']
    when 'checkout.session.completed'
      session = event['data']['object']
      user_id = session['client_reference_id']
      user = User.find(user_id)
      user.update!(subscription_status: 'active', stripe_customer_id: session['customer'])
    end

    render json: { received: true }
  end
end
