require 'rails_helper'

RSpec.describe Stripe::SubscriptionService, type: :service do
  let(:user) { create(:user, email: 'test@example.com') }
  let(:service) { Stripe::SubscriptionService.new(user) }

  before do
    stub_const("ENV", ENV.to_hash.merge(
      "STRIPE_SECRET_KEY" => "sk_test_123",
      "STRIPE_PRICE_ID" => "price_test_123"
    ))
  end

  describe '#create_customer' do
    context 'when user has no Stripe customer ID' do
      let(:stripe_customer) { double("customer", id: "cus_test_123") }

      before do
        allow(::Stripe::Customer).to receive(:create).and_return(stripe_customer)
      end

      it 'creates a Stripe customer' do
        expect(::Stripe::Customer).to receive(:create).with(
          email: user.email,
          metadata: { user_id: user.id }
        )

        customer_id = service.create_customer

        expect(customer_id).to eq("cus_test_123")
      end

      it 'updates user with Stripe customer ID' do
        allow(::Stripe::Customer).to receive(:create).and_return(stripe_customer)

        expect { service.create_customer }.to change { user.reload.stripe_customer_id }.to("cus_test_123")
      end
    end

    context 'when user already has Stripe customer ID' do
      let(:user) { create(:user, stripe_customer_id: "cus_existing_123") }

      it 'returns existing customer ID without creating new one' do
        expect(::Stripe::Customer).not_to receive(:create)

        customer_id = service.create_customer

        expect(customer_id).to eq("cus_existing_123")
      end
    end
  end

  describe '#create_checkout_session' do
    let(:checkout_session) { double("session", id: "cs_test_123", url: "https://checkout.stripe.com/pay/cs_test_123") }
    let(:success_url) { "https://example.com/success" }
    let(:cancel_url) { "https://example.com/cancel" }

    before do
      allow(service).to receive(:create_customer).and_return("cus_test_123")
      allow(::Stripe::Checkout::Session).to receive(:create).and_return(checkout_session)
    end

    it 'creates a checkout session with correct parameters' do
      expect(::Stripe::Checkout::Session).to receive(:create).with(
        customer: "cus_test_123",
        mode: "subscription",
        payment_method_collection: "always",
        line_items: [{ price: "price_test_example", quantity: 1 }],
        success_url: success_url,
        cancel_url: cancel_url,
        subscription_data: {
          trial_period_days: 5,
          metadata: { user_id: user.id }
        }
      )

      result = service.create_checkout_session(success_url: success_url, cancel_url: cancel_url)

      expect(result).to eq(checkout_session)
    end

    it 'ensures customer exists before creating session' do
      expect(service).to receive(:create_customer)

      service.create_checkout_session(success_url: success_url, cancel_url: cancel_url)
    end
  end

  describe '#create_portal_session' do
    let(:portal_session) { double("portal_session", url: "https://billing.stripe.com/session/test") }
    let(:return_url) { "https://example.com/return" }

    context 'when user has Stripe customer ID' do
      let(:user) { create(:user, stripe_customer_id: "cus_test_123") }

      before do
        allow(::Stripe::BillingPortal::Session).to receive(:create).and_return(portal_session)
      end

      it 'creates a portal session' do
        expect(::Stripe::BillingPortal::Session).to receive(:create).with(
          customer: "cus_test_123",
          return_url: return_url
        )

        result = service.create_portal_session(return_url: return_url)

        expect(result).to eq(portal_session)
      end
    end

    context 'when user has no Stripe customer ID' do
      it 'raises an error' do
        expect {
          service.create_portal_session(return_url: return_url)
        }.to raise_error("User has no Stripe customer ID")
      end
    end
  end
end