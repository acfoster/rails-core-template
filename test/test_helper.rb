ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Setup Devise mappings for integration tests
  setup do
    @request = ActionDispatch::TestRequest.create if defined?(@request).nil?
    Devise.mappings[:user] ||= Devise.add_mapping(:user, class_name: "User")
  end
end
