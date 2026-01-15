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
      post webhooks_stripe_path, params: event_data.to_json, headers: {
        "Content-Type" => "application/json",
        "Stripe-Signature" => "test_signature"
      }
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

      post webhooks_stripe_path, params: event_data.to_json, headers: {
        "Content-Type" => "application/json",
        "Stripe-Signature" => "test_signature"
      }
      expect(response).to have_http_status(:success)
    end
  end
end
