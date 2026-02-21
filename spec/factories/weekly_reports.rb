FactoryBot.define do
  factory :weekly_report do
    user
    week_start { Date.current - AiReportService::DEFAULT_PERIOD_DAYS }
    week_end { Date.current - 1 }
    content { "## 📊 今週の振り返り\n\n体調は安定していました。\n\n## 🔍 傾向分析\n\n- 睡眠時間は平均7時間でした\n- 運動は週3回行いました" }
    summary_data { { record_count: 5, avg_mood: 3.5, avg_sleep: 7.0, total_exercise: 90 } }
    predictions { { warning_dates: [], forecast_days: 7 } }
    tokens_used { 1500 }

    trait :with_warnings do
      predictions do
        {
          warning_dates: [
            (Date.current + 2.days).to_s,
            (Date.current + 4.days).to_s
          ],
          forecast_days: 7
        }
      end
    end
  end
end
