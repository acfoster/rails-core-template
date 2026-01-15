require 'rails_helper'

RSpec.describe "Users", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe "GET /profile" do
    it "returns http success" do
      get profile_path
      expect(response).to have_http_status(:success)
    end

    it "displays user email" do
      get profile_path
      expect(response.body).to include(user.email)
    end
  end

  describe "GET /profile/account" do
    it "returns http success" do
      get profile_account_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /profile/payment" do
    it "returns http success" do
      get profile_payment_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /profile/billing" do
    it "returns http success" do
      get profile_billing_path
      expect(response).to have_http_status(:success)
    end
  end
end
