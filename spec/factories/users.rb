FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }

    trait :with_location do
      latitude { 35.6895 }
      longitude { 139.6917 }
      location_name { "東京都" }
    end
  end
end
