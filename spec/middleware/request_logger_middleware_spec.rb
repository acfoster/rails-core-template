require 'rails_helper'

RSpec.describe RequestLoggerMiddleware do
  let(:app) { double('app') }
  let(:middleware) { described_class.new(app) }
  let(:user) { build_stubbed(:user) }
  let(:warden) { double('warden') }
  let(:request) { instance_double(ActionDispatch::Request) }
  let(:env) { 
    {
      'REQUEST_METHOD' => 'GET',
      'PATH_INFO' => '/dashboard',
      'REMOTE_ADDR' => '192.168.1.1',
      'HTTP_USER_AGENT' => 'RSpec/Test',
      'warden' => warden,
      'action_dispatch.request.path_parameters' => { controller: 'dashboard' }
    }
  }

  before do
    allow(app).to receive(:call).with(env).and_return([200, {}, ['response']])
    allow(ActionDispatch::Request).to receive(:new).with(env).and_return(request)
    allow(request).to receive(:request_id).and_return('req-123')
    allow(request).to receive(:remote_ip).and_return('192.168.1.1')
    allow(request).to receive(:method).and_return('GET')
    allow(request).to receive(:path).and_return('/dashboard')
    allow(request).to receive(:path_info).and_return('/dashboard')
    allow(warden).to receive(:user).and_return(user)
    allow(user).to receive(:admin?).and_return(false)
    allow(user).to receive(:subscription_status).and_return('trialing')
  end

  describe '#call' do
    it 'logs request with minimal user data (user_id only)' do
      expect(middleware).to receive(:emit_request_log).with(hash_including(
        log_type: 'http_request',
        level: 'info',
        message: 'HTTP request completed',
        user_id: user.id,
        metadata: hash_including(
          user_id: user.id,
          role: 'user',
          subscription_status: 'trialing'
        )
      )) do |args|
        # Verify that full user object is NOT included
        expect(args.keys).not_to include(:user)
        expect(args[:context]).to be_a(Hash)
        expect(args[:context][:method]).to eq('GET')
      end

      middleware.call(env)
    end

    it 'handles nil user gracefully' do
      allow(warden).to receive(:user).and_return(nil)
      
      expect(middleware).to receive(:emit_request_log).with(hash_including(
        user_id: nil,
        metadata: nil
      ))
      
      middleware.call(env)
    end

    it 'limits payload size for large contexts' do
      # Mock a large context response
      large_path = '/test/' + 'x' * 3000
      allow(request).to receive(:path).and_return(large_path)
      allow(request).to receive(:path_info).and_return(large_path)
      
      expect(middleware).to receive(:emit_request_log) do |args|
        expect(args[:context]).to have_key(:truncated)
        expect(args[:context][:truncated]).to be true
      end
      
      middleware.call(env)
    end

    context 'when request fails (4xx/5xx)' do
      before do
        allow(app).to receive(:call).with(env).and_return([400, {}, ['Bad Request']])
      end

      it 'db logs error/slow requests with minimal user data' do
        expect(Log).to receive(:log).with(hash_including(
          log_type: 'http_request',
          level: 'warning',
          user_id: user.id,
          metadata: hash_including(user_id: user.id, role: 'user')
        )) do |args|
          # Verify full user object is not included
          expect(args.keys).not_to include(:user)
        end

        middleware.call(env)
      end
    end

    context 'when app raises an error' do
      before do
        allow(app).to receive(:call).and_raise(StandardError.new('Test error'))
      end

      it 'logs error with minimal user data' do
        expect(Log).to receive(:log).with(hash_including(
          log_type: 'error',
          level: 'error',
          user_id: user.id,
          context: hash_including(
            error: 'Test error',
            error_class: 'StandardError'
          )
        )) do |args|
          # Verify full user object is not included
          expect(args.keys).not_to include(:user)
        end

        expect { middleware.call(env) }.to raise_error(StandardError, 'Test error')
      end
    end
  end
end
