FactoryBot.define do
  factory :log do
    log_type { "user_action" }
    level { "info" }
    action { "test_action" }
    message { "Test log message" }
    user { nil }
    controller { "test_controller" }
    request_id { SecureRandom.uuid }
    ip_address { "127.0.0.1" }
    context { {} }
    metadata { {} }
    occurred_at { Time.current }
  end
end
