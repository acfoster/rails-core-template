require 'rails_helper'

RSpec.describe BotBlockingMiddleware, type: :middleware do
  let(:app) { ->(env) { [200, {}, ['OK']] } }
  let(:middleware) { described_class.new(app) }

  def make_request(path: '/', user_agent: 'Mozilla/5.0', query_string: '')
    env = Rack::MockRequest.env_for("http://example.com#{path}?#{query_string}")
    env['HTTP_USER_AGENT'] = user_agent
    middleware.call(env)
  end

  describe 'WordPress path blocking' do
    it 'fast blocks /wp-admin/ requests with 410' do
      status, headers, body = make_request(path: '/wp-admin/setup-config.php')
      expect(status).to eq(410) # Fast block returns 410 Gone
      expect(headers['Content-Type']).to eq('text/plain')
      expect(body).to eq(['Gone'])
    end

    it 'fast blocks WordPress probe paths' do
      fast_block_paths = [
        '/wp-login.php',
        '/xmlrpc.php', 
        '/index.php',
        '/admin.php',
        '/phpmyadmin/index.php'
      ]
      
      fast_block_paths.each do |path|
        status, _, _ = make_request(path: path)
        expect(status).to eq(410), "Expected 410 for #{path}"
      end
    end

    it 'blocks other WordPress paths with 404' do
      status, headers, body = make_request(path: '/blog/wp-admin/')
      expect(status).to eq(404)
    end

    it 'allows normal application paths' do
      status, headers, body = make_request(path: '/dashboard')
      expect(status).to eq(200)
    end

    it 'allows .well-known paths (needed for SSL)' do
      status, headers, body = make_request(path: '/.well-known/acme-challenge/test')
      expect(status).to eq(200)
    end
  end

  describe 'User agent blocking' do
    it 'blocks python-requests' do
      status, headers, body = make_request(user_agent: 'python-requests/2.28.0')
      expect(status).to eq(404)
    end

    it 'blocks wget' do
      status, headers, body = make_request(user_agent: 'Wget/1.20.3')
      expect(status).to eq(404)
    end

    it 'allows legitimate browsers' do
      status, headers, body = make_request(user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
      expect(status).to eq(200)
    end

    it 'allows Google crawler' do
      status, headers, body = make_request(user_agent: 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)')
      expect(status).to eq(200)
    end
  end

  describe 'Suspicious query parameter blocking' do
    it 'blocks directory traversal attempts' do
      status, headers, body = make_request(query_string: 'file=../../../etc/passwd')
      expect(status).to eq(404)
    end

    it 'blocks SQL injection attempts' do
      status, headers, body = make_request(query_string: 'id=1 UNION SELECT * FROM users')
      expect(status).to eq(404)
    end

    it 'allows normal query parameters' do
      status, headers, body = make_request(query_string: 'symbol=AAPL&timeframe=1h')
      expect(status).to eq(200)
    end
  end

  describe 'Common attack path blocking' do
    attack_paths = [
      '/phpmyadmin/',
      '/administrator/',
      '/.env',
      '/.git/',
      '/config.php',
      '/backup/',
      '/cgi-bin/test.cgi'
    ]

    attack_paths.each do |path|
      it "blocks #{path}" do
        status, headers, body = make_request(path: path)
        expected_status = path.match?(%r{\A/(phpmyadmin/|\.env|\.git/|config\.php|backup/|cgi-bin/)}) ? 410 : 404
        expect(status).to eq(expected_status)
      end
    end
  end

  it 'logs blocked requests' do
    expect(Rails.logger).to receive(:info).with(/\[BOT_FAST_BLOCK\]/)
    make_request(path: '/wp-admin/')
  end
end
