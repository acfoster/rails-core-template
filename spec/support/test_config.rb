module TestConfig
  # Check if we should use real APIs for testing
  def self.use_real_apis?
    ENV['USE_REAL_APIS'] == 'true'
  end

  # Check if specific service keys are available
  def self.openai_available?
    ENV['OPENAI_API_KEY'].present?
  end

  def self.stripe_available?
    ENV['STRIPE_SECRET_KEY'].present? && ENV['STRIPE_PUBLISHABLE_KEY'].present?
  end

  def self.cloudmersive_available?
    ENV['CLOUDMERSIVE_API_KEY'].present?
  end

  def self.all_apis_available?
    openai_available? && stripe_available? && cloudmersive_available?
  end

  # Test configuration helpers
  def self.configure_for_real_testing
    return unless use_real_apis?
    
    puts "🔧 Configuring tests for REAL API integration..."
    puts "  - OpenAI: #{'✅' if openai_available?}"
    puts "  - Stripe: #{'✅' if stripe_available?}"
    puts "  - Cloudmersive: #{'✅' if cloudmersive_available?}"
    puts "  - All APIs: #{'✅' if all_apis_available?}"
  end
end

# Auto-configure when loaded
TestConfig.configure_for_real_testing