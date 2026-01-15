require 'rails_helper'

RSpec.describe "Subscriptions", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
    # Mock Stripe API key check
    allow(::Stripe).to receive(:api_key=)
  end

  describe "GET /new" do
    it "returns http success" do
      get new_subscription_path
      expect(response).to have_http_status(:success)
    end

    it "displays subscription page with branding" do
      get new_subscription_path
      expect(response.body).to include("Subscribe to Core App Template")
      expect(response.body).to include("$5")
      expect(response.body).to include("Subscription management")
    end

    context "when trial is expired" do
      let(:user) { create(:user, trial_ends_at: 1.day.ago, subscription_status: 'trialing') }

      it "shows expired trial message" do
        get new_subscription_path
        expect(response.body).to include("Subscribe to Core App Template")
        expect(response.body).to include("Choose a plan")
      end
    end

    context "when trial is active" do
      let(:user) { create(:user, trial_ends_at: 5.days.from_now, subscription_status: 'trialing') }

      it "shows general subscription message" do
        get new_subscription_path
        expect(response.body).to include("Choose a plan")
      end
    end
  end

  describe "POST /create" do
    let(:checkout_session) {
      double("checkout_session",
        id: "cs_test_123",
        url: "https://checkout.stripe.com/pay/cs_test_123"
      )
    }
    let(:stripe_customer) {
      double("customer", id: "cus_test_123")
    }

    before do
      # Mock environment variables
      allow(ENV).to receive(:fetch).with("STRIPE_SECRET_KEY").and_return("sk_test_fake_key")
      allow(ENV).to receive(:fetch).with("STRIPE_PUBLISHABLE_KEY").and_return("pk_test_fake_key")
      allow(ENV).to receive(:fetch).and_call_original
      
      # Mock Stripe API configuration
      allow(::Stripe).to receive(:api_key=)
      
      # Mock the entire service to return our test objects
      subscription_service = instance_double(Stripe::SubscriptionService)
      allow(Stripe::SubscriptionService).to receive(:new).and_return(subscription_service)
      allow(subscription_service).to receive(:create_checkout_session).and_return(checkout_session)
    end

    it "creates a checkout session and redirects to Stripe" do
      post subscription_path
      expect(response).to redirect_to(checkout_session.url)
    end

    it "creates checkout session with correct parameters" do
      subscription_service = Stripe::SubscriptionService.new(user)
      expect(Stripe::SubscriptionService).to receive(:new).with(user).and_return(subscription_service)
      expect(subscription_service).to receive(:create_checkout_session).with(hash_including(
        success_url: dashboard_url,
        cancel_url: new_subscription_url
      )).and_return(checkout_session)

      post subscription_path
    end
  end

  describe "GET /portal" do
    let(:user) { create(:user, stripe_customer_id: "cus_test_123") }
    let(:portal_session) {
      double("portal_session", 
        id: "bps_test_123",
        url: "https://billing.stripe.com/session/test"
      )
    }

    before do
      # Mock environment variables
      allow(ENV).to receive(:fetch).with("STRIPE_SECRET_KEY").and_return("sk_test_fake_key")
      allow(ENV).to receive(:fetch).with("STRIPE_PUBLISHABLE_KEY").and_return("pk_test_fake_key")
      allow(ENV).to receive(:fetch).and_call_original
      
      # Mock Stripe API configuration
      allow(::Stripe).to receive(:api_key=)
      
      # Mock the entire service to return our test objects
      subscription_service = instance_double(Stripe::SubscriptionService)
      allow(Stripe::SubscriptionService).to receive(:new).and_return(subscription_service)
      allow(subscription_service).to receive(:create_portal_session).and_return(portal_session)
    end

    it "creates a portal session and redirects to Stripe" do
      get portal_subscription_path
      expect(response).to redirect_to(portal_session.url)
    end
  end
end
