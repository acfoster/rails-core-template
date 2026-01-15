require 'rails_helper'

RSpec.describe 'Bot probe protection', type: :request do
  describe 'WordPress probe attempts' do
    let(:bot_probe_paths) do
      %w[
        /wp-admin/setup-config.php
        /wordpress/wp-admin/admin.php
        /xmlrpc.php
        /wp-login.php
        /index.php
        /admin.php
        /phpmyadmin/index.php
        /.env
        /.git/config
      ]
    end

    it 'returns fast 410 responses for bot probe paths without raising RoutingError' do
      bot_probe_paths.each do |path|
        expect {
          get path
        }.not_to raise_error

        expect(response.status).to eq(410)
        expect(response.body).to eq('Gone')
        expect(response.content_type).to eq('text/plain')
      end
    end

    it 'does not generate Rails request logs for blocked bot requests' do
      # Capture log output
      log_output = StringIO.new
      old_logger = Rails.logger
      Rails.logger = Logger.new(log_output)

      begin
        get '/wp-admin/setup-config.php'
        
        log_content = log_output.string
        
        # Should have bot blocking log but not Rails routing logs
        expect(log_content).to match(/BOT_FAST_BLOCK/)
        expect(log_content).not_to match(/ActionController::RoutingError/)
        expect(log_content).not_to match(/No route matches/)
      ensure
        Rails.logger = old_logger
      end
    end

    it 'masks IP addresses in bot blocking logs' do
      log_output = StringIO.new
      old_logger = Rails.logger
      Rails.logger = Logger.new(log_output)

      begin
        get '/wp-admin/setup-config.php', headers: { 'REMOTE_ADDR' => '203.0.113.1' }
        
        log_content = log_output.string
        
        # Should contain hashed IP (8 character hash) in bot block log
        expect(log_content).to match(/\[BOT_FAST_BLOCK\].*ip=[a-f0-9]{8}/)
      ensure
        Rails.logger = old_logger
      end
    end

    it 'handles bot requests with malicious user agents' do
      bot_user_agents = [
        'python-requests/2.31.0',
        'curl/7.81.0',
        'Go-http-client/1.1',
        'zgrab/0.x'
      ]

      bot_user_agents.each do |ua|
        expect {
          get '/', headers: { 'HTTP_USER_AGENT' => ua }
        }.not_to raise_error

        expect(response.status).to eq(404) # Regular bot blocking, not fast block
      end
    end
  end

  describe 'legitimate requests' do
    it 'allows normal application paths through' do
      legitimate_paths = %w[/ /dashboard /users/sign_in /contact]
      
      legitimate_paths.each do |path|
        get path, headers: { 'HTTP_USER_AGENT' => 'Mozilla/5.0 (legitimate browser)' }
        
        # These may 404 or redirect due to authentication, but shouldn't be blocked
        expect(response.status).not_to eq(410)
        expect(response.status).not_to eq(429)
      end
    end

    it 'preserves .well-known paths for SSL verification' do
      get '/.well-known/acme-challenge/test-challenge'
      
      # Should not be blocked (may 404 normally)
      expect(response.status).not_to eq(410)
      expect(response.status).not_to eq(429)
    end
  end
end
