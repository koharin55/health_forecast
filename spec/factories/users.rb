FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    nickname { "テストユーザー" }

    trait :without_nickname do
      nickname { nil }
    end

    trait :with_location do
      latitude { 35.6895 }
      longitude { 139.6917 }
      location_name { "東京都" }
    end

    trait :with_api_token do
      transient do
        raw_api_token { SecureRandom.hex(32) }
      end

      api_token_digest { Digest::SHA256.hexdigest(raw_api_token) }

      after(:create) do |user, evaluator|
        user.instance_variable_set(:@raw_api_token, evaluator.raw_api_token)
        user.define_singleton_method(:raw_api_token) { @raw_api_token }
      end
    end
  end
end
