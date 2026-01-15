require 'rails_helper'

RSpec.describe 'Rack::Attack', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  before do
    # Enable rack-attack for testing
    @rack_attack_enabled = Rack::Attack.enabled
    @rack_attack_store = Rack::Attack.cache.store
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.cache.store.clear
  end

  after do
    Rack::Attack.cache.store.clear
    Rack::Attack.cache.store = @rack_attack_store
    Rack::Attack.enabled = @rack_attack_enabled
  end

  describe 'suspicious paths throttling' do
    let(:suspicious_paths) do
      %w[
        /suspicious.php
        /wordpress.php
      ]
    end

    it 'throttles suspicious paths after 5 requests in 30 seconds' do
      suspicious_paths.each do |path|
        # First 5 requests should pass through without rack-attack throttling
        5.times do
          get path
        end

        # 6th request should be throttled by rack-attack
        get path
        expect(response.status).to eq(429)
        expect(response.headers['Retry-After']).to be_present
      end
    end

    it 'resets throttle after period expires' do
      path = '/suspicious.php'
      
      # Hit limit
      6.times { get path }
      get path
      expect(response.status).to eq(429)
      
      # Travel forward in time
      travel 31.seconds do
        head path
        expect(response.status).not_to eq(429)
      end
    end
  end

  describe 'bot POST targets throttling' do
    let(:bot_post_paths) { %w[/ /admin /api] }

    it 'throttles POST requests to bot target paths' do
      bot_post_paths.each do |path|
        # First 10 requests should pass through
        10.times do
          post path, params: { test: 'data' }
        end

        # 11th request should be throttled
        post path, params: { test: 'data' }
        expect(response.status).to eq(429)
      end
    end

    it 'does not throttle GET requests to same paths' do
      bot_post_paths.each do |path|
        15.times do
          get path
          expect(response.status).not_to eq(429)
        end
      end
    end
  end

  describe 'general rate limiting' do
    it 'allows 100 requests per minute from same IP' do
      100.times do |i|
        get '/', headers: { 'REMOTE_ADDR' => '203.0.113.1' }
        expect(response.status).not_to eq(429), "Request #{i + 1} was throttled"
      end

      # 101st request should be throttled
      get '/', headers: { 'REMOTE_ADDR' => '203.0.113.1' }
      expect(response.status).to eq(429)
    end

    it 'treats different IPs separately' do
      50.times do
        get '/', headers: { 'REMOTE_ADDR' => '203.0.113.1' }
        get '/', headers: { 'REMOTE_ADDR' => '203.0.113.2' }
      end

      # Both IPs should still be able to make requests
      get '/', headers: { 'REMOTE_ADDR' => '203.0.113.1' }
      expect(response.status).not_to eq(429)
      
      get '/', headers: { 'REMOTE_ADDR' => '203.0.113.2' }
      expect(response.status).not_to eq(429)
    end
  end

  describe 'Cloudflare IP extraction' do
    it 'uses CF-Connecting-IP when present' do
      real_ip = '203.0.113.1'
      proxy_ip = '172.16.0.1'

      # Make requests with Cloudflare headers
      50.times do
        get '/', headers: { 
          'REMOTE_ADDR' => proxy_ip,
          'HTTP_CF_CONNECTING_IP' => real_ip
        }
      end

      # Should be close to rate limit for the real IP
      50.times do
        get '/', headers: { 
          'REMOTE_ADDR' => proxy_ip,
          'HTTP_CF_CONNECTING_IP' => real_ip
        }
      end

      # Should be throttled now
      get '/', headers: { 
        'REMOTE_ADDR' => proxy_ip,
        'HTTP_CF_CONNECTING_IP' => real_ip
      }
      expect(response.status).to eq(429)

      # But proxy IP alone should still work
      get '/', headers: { 'REMOTE_ADDR' => proxy_ip }
      expect(response.status).not_to eq(429)
    end
  end

  describe 'auth endpoints protection' do
    let(:auth_paths) { %w[/users/sign_in /users/password /users/sign_up] }

    it 'throttles auth endpoint attempts' do
      auth_paths.each do |path|
        # 20 attempts should be allowed
        20.times do
          post path, params: { user: { email: 'test@example.com' } }
          # Don't check status here as these will likely 404/422 without proper setup
        end

        # 21st should be throttled
        post path, params: { user: { email: 'test@example.com' } }
        expect(response.status).to eq(429)
      end
    end
  end

  describe 'throttle response' do
    it 'includes rate limit headers in throttled response' do
      # Hit general rate limit
      101.times { get '/' }
      
      get '/'
      expect(response.status).to eq(429)
      expect(response.headers['Retry-After']).to be_present
      expect(response.headers['X-RateLimit-Limit']).to eq('100')
      expect(response.headers['X-RateLimit-Remaining']).to eq('0')
      expect(response.headers['X-RateLimit-Reset']).to be_present
      expect(response.body).to eq('Rate limit exceeded. Please try again later.')
    end
  end
end
