require 'rails_helper'

RSpec.describe 'User Subscription Workflow Integration', type: :request do
  let(:user) { create(:user, subscription_status: 'trialing', email: 'sub_test@example.com') }

  before do
    sign_in user
    # Mock Stripe environment
    allow(ENV).to receive(:fetch).with("STRIPE_SECRET_KEY").and_return("sk_test_fake_key")
    allow(ENV).to receive(:fetch).with("STRIPE_PUBLISHABLE_KEY").and_return("pk_test_fake_key")
    allow(ENV).to receive(:fetch).and_call_original
    allow(::Stripe).to receive(:api_key=)
  end

  describe 'subscription creation flow' do
    context 'successful checkout session creation' do
      let(:checkout_session) {
        double("checkout_session", 
          id: "cs_test_123",
          url: "https://checkout.stripe.com/pay/cs_test_123"
        )
      }

      before do
        subscription_service = instance_double(Stripe::SubscriptionService)
        allow(Stripe::SubscriptionService).to receive(:new).and_return(subscription_service)
        allow(subscription_service).to receive(:create_checkout_session).and_return(checkout_session)
      end

      it 'creates checkout session and redirects to Stripe' do
        post subscription_path

        expect(response).to redirect_to(checkout_session.url)
      end
    end

    context 'when Stripe service fails' do
      before do
        allow_any_instance_of(Stripe::SubscriptionService).to receive(:create_checkout_session).and_raise(
          StandardError.new("Stripe API error")
        )
      end

      it 'handles errors gracefully' do
        post subscription_path

        expect(response).to redirect_to(new_subscription_path)
        expect(flash[:alert]).to include('Unable to start checkout')
      end
    end
  end

  describe 'subscription portal access' do
    let(:portal_user) { create(:user, stripe_customer_id: "cus_test_123", subscription_status: 'active', email: 'portal_test@example.com') }
    let(:portal_session) {
      double("portal_session", 
        id: "bps_test_123",
        url: "https://billing.stripe.com/session/test"
      )
    }

    before do
      subscription_service = instance_double(Stripe::SubscriptionService)
      allow(Stripe::SubscriptionService).to receive(:new).and_return(subscription_service)
      allow(subscription_service).to receive(:create_portal_session).and_return(portal_session)
      sign_in portal_user
    end

    it 'creates portal session for existing customers' do
      get portal_subscription_path

      expect(response).to redirect_to(portal_session.url)
    end
  end

  describe 'webhook handling' do
    let(:webhook_payload) {
      {
        id: "evt_test",
        type: "customer.subscription.updated",
        data: {
          object: {
            id: "sub_test",
            customer: user.stripe_customer_id || "cus_test",
            status: "active"
          }
        }
      }
    }

    before do
      stub_const("ENV", ENV.to_hash.merge(
        "STRIPE_WEBHOOK_SECRET" => "test_secret",
        "STRIPE_SECRET_KEY" => "sk_test_fake_key"
      ))

      allow(::Stripe::Webhook).to receive(:construct_event).and_return(
        double("event", 
          id: "evt_test_123",
          type: "customer.subscription.updated",
          livemode: false,
          data: double("data", object: double("object", 
            id: "sub_test", 
            customer: "cus_test", 
            status: "active"
          ))
        )
      )
    end

    it 'processes subscription update webhooks' do
      post webhooks_stripe_path, 
        params: webhook_payload.to_json, 
        headers: {
          "Content-Type" => "application/json",
          "Stripe-Signature" => "test_signature"
        }

      expect(response).to have_http_status(:success)
    end
  end
end