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

    trait :with_weather do
      weather_temperature { 18.5 }
      weather_humidity { 55 }
      weather_pressure { 1013.2 }
      weather_code { 1 }
      weather_description { "晴れ" }
    end

    trait :with_low_pressure do
      weather_temperature { 15.0 }
      weather_humidity { 80 }
      weather_pressure { 998.5 }
      weather_code { 61 }
      weather_description { "弱い雨" }
    end

    trait :complete do
      with_blood_pressure
      with_temperature
      with_exercise
      with_weather
      steps { 8000 }
      heart_rate { 70 }
      notes { "今日も元気に過ごせました" }
    end
  end
end
