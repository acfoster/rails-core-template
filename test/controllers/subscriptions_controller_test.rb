require 'test_helper'

class SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  # Test #create with confirmed user
  test "create redirects to Stripe checkout for confirmed user" do
    user = User.new(email: "test1@example.com", password: "Password123!")
    user.skip_confirmation!
    user.save!
    sign_in user

    mock_session = OpenStruct.new(id: "cs_test_123", url: "https://checkout.stripe.com/test")
    mock_service = Object.new
    mock_service.define_singleton_method(:create_checkout_session) do |**_params|
      mock_session
    end

    Stripe::SubscriptionService.stub :new, mock_service do
      post subscription_path

      assert_redirected_to "https://checkout.stripe.com/test"
    end
  end

  test "create blocks unconfirmed user and does not call Stripe" do
    user = User.new(email: "test2@example.com", password: "Password123!")
    user.save!
    sign_in user

    # Ensure Stripe service is never instantiated
    Stripe::SubscriptionService.stub :new, ->(_) { raise "Stripe should not be called" } do
      post subscription_path

      assert_redirected_to new_user_session_path
    end
  end

  # Test #portal with confirmed user
  test "portal redirects to Stripe portal for confirmed user" do
    user = User.new(email: "test3@example.com", password: "Password123!")
    user.skip_confirmation!
    user.save!
    sign_in user

    mock_session = OpenStruct.new(id: "bps_test_123", url: "https://billing.stripe.com/test")
    mock_service = Object.new
    mock_service.define_singleton_method(:create_portal_session) do |**_params|
      mock_session
    end

    Stripe::SubscriptionService.stub :new, mock_service do
      get portal_subscription_path

      assert_redirected_to "https://billing.stripe.com/test"
    end
  end

  test "portal blocks unconfirmed user and does not call Stripe" do
    user = User.new(email: "test4@example.com", password: "Password123!")
    user.save!
    sign_in user

    # Ensure Stripe service is never instantiated
    Stripe::SubscriptionService.stub :new, ->(_) { raise "Stripe should not be called" } do
      get portal_subscription_path

      assert_redirected_to new_user_session_path
    end
  end

  # Test #new (should not be blocked)
  test "new shows subscription page for confirmed user" do
    user = User.new(email: "test5@example.com", password: "Password123!")
    user.skip_confirmation!
    user.save!
    sign_in user

    get new_subscription_path

    assert_response :success
  end
end
