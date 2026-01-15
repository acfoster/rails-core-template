require 'rails_helper'

RSpec.describe "Admin::Logs", type: :request do
  let(:admin) { create(:admin_user) }
  let(:user) { create(:user) }
  let!(:log) { create(:log, user: user) }

  before do
    sign_in admin
  end

  describe "GET /index" do
    it "returns http success" do
      get admin_logs_path
      expect(response).to have_http_status(:success)
    end

    it "displays logs" do
      get admin_logs_path
      expect(response.body).to include(log.message)
    end

    it "filters by log type" do
      error_log = create(:log, log_type: "error", user: user)
      get admin_logs_path, params: { log_type: "error" }
      expect(response.body).to include(error_log.message)
    end

    it "filters by level" do
      error_log = create(:log, level: "error", user: user)
      get admin_logs_path, params: { level: "error" }
      expect(response.body).to include(error_log.message)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get admin_log_path(log)
      expect(response).to have_http_status(:success)
    end

    it "displays log details" do
      get admin_log_path(log)
      expect(response.body).to include(log.message)
      expect(response.body).to include(log.user.email)
    end
  end
end
