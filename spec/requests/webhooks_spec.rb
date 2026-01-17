require 'rails_helper'

RSpec.describe "Webhooks", type: :request do
  describe "POST /webhooks/stripe" do
    let(:event_data) {
      {
        id: "evt_test",
        type: "customer.subscription.updated",
        data: {
          object: {
            id: "sub_test",
            customer: "cus_test",
            status: "active"
          }
        }
      }
    }
    let(:headers) {
      {
        "Content-Type" => "application/json",
        "Stripe-Signature" => "test_signature"
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
          data: double("data", object: double("object", id: "sub_test", customer: "cus_test", status: "active"))
        )
      )
    end

    it "returns http success" do
      post webhooks_stripe_path, params: event_data.to_json, headers: headers
      expect(response).to have_http_status(:success)
    end

    it "handles unknown event types gracefully" do
      allow(::Stripe::Webhook).to receive(:construct_event).and_return(
        double("event", 
          id: "evt_unknown_123", 
          type: "unknown.event", 
          livemode: false,
          data: double("data", object: {}))
      )

      post webhooks_stripe_path, params: event_data.to_json, headers: headers
      expect(response).to have_http_status(:success)
    end

    it "returns success even when event processing raises an error" do
      allow(Stripe::SubscriptionService).to receive(:handle_webhook_event).and_raise(StandardError, "boom")

      post webhooks_stripe_path, params: event_data.to_json, headers: headers
      expect(response).to have_http_status(:success)
    end

    it "returns bad request for invalid signature" do
      allow(::Stripe::Webhook).to receive(:construct_event).and_raise(
        ::Stripe::SignatureVerificationError.new("bad signature", "sig_header")
      )

      post webhooks_stripe_path, params: event_data.to_json, headers: headers
      expect(response).to have_http_status(:bad_request)
    end

    it "returns bad request for invalid JSON payload" do
      allow(::Stripe::Webhook).to receive(:construct_event).and_raise(
        JSON::ParserError.new("unexpected token")
      )

      post webhooks_stripe_path, params: "{invalid_json", headers: headers
      expect(response).to have_http_status(:bad_request)
    end
  end
end
