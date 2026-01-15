FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    subscription_status { "trialing" }
    trial_ends_at { 5.days.from_now }
    confirmed_at { Time.current }

    # Allow tests to override trial_ends_at without the callback interfering
    after(:build) do |user|
      # Skip callbacks when explicitly setting trial_ends_at
      user.instance_variable_set(:@skip_trial_setup, user.trial_ends_at.present?)
    end

    trait :admin do
      role { :admin }
    end
  end

  # Alias for backwards compatibility
  factory :admin_user, parent: :user, traits: [:admin]
end
