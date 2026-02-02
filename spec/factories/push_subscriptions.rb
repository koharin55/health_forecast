FactoryBot.define do
  factory :push_subscription do
    user
    sequence(:endpoint) { |n| "https://push.example.com/subscription/#{n}" }
    p256dh_key { "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkA" }
    auth_key { "tBHItJI5svbpez7KI4CCXg" }
    user_agent { "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" }
    active { true }
    last_used_at { nil }

    trait :inactive do
      active { false }
    end
  end
end
