RSpec.configure do |config|
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Warden::Test::Helpers, type: :system

  # Configure Devise mappings for User
  config.before(:each, type: :request) do
    # Ensure Devise mappings are loaded
    Devise.mappings[:user] ||= Devise.add_mapping(:user, class_name: 'User')
    Warden.test_mode!
  end

  # Clean up after Warden in system tests
  config.after(:each, type: :system) do
    Warden.test_reset!
  end

  # Clean up after Warden in request specs
  config.after(:each, type: :request) do
    Warden.test_reset!
  end
end
