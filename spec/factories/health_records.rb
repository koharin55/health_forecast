FactoryBot.define do
  factory :health_record do
    user
    recorded_at { Date.current }
    mood { 3 }
    weight { 65.0 }
    sleep_hours { 7.5 }

    trait :with_blood_pressure do
      systolic_pressure { 120 }
      diastolic_pressure { 80 }
    end

    trait :with_temperature do
      body_temperature { 36.5 }
    end

    trait :with_exercise do
      exercise_minutes { 30 }
    end

    trait :complete do
      with_blood_pressure
      with_temperature
      with_exercise
      steps { 8000 }
      heart_rate { 70 }
      notes { "今日も元気に過ごせました" }
    end
  end
end
