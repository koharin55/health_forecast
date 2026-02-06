# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding database..."

# テストユーザーの作成
user = User.find_or_create_by!(email: "test@example.com") do |u|
  u.password = "password"
  u.password_confirmation = "password"
end

puts "✅ Created test user: #{user.email}"

# 既存の記録を削除
user.health_records.destroy_all

# 30日分の健康記録を作成
puts "📊 Creating 30 days of health records..."

30.downto(0) do |days_ago|
  date = Date.current - days_ago.days

  # 体重: 70kg から徐々に減少（ランダムな変動あり）
  base_weight = 70.0 - (days_ago * 0.05)
  weight = base_weight + rand(-0.3..0.3)

  # 睡眠時間: 6.5-8.5時間
  sleep_hours = rand(6.5..8.5).round(1)

  # 運動時間: 0-60分（週末は長め）
  is_weekend = date.wday == 0 || date.wday == 6
  exercise_minutes = is_weekend ? rand(20..60) : rand(0..40)

  # 歩数: 4000-12000歩
  steps = rand(4000..12000)

  # 心拍数: 60-80 bpm
  heart_rate = rand(60..80)

  # 体調スコア: 1-5（最近は良い傾向）
  mood_probability = days_ago > 15 ? [1, 2, 3, 3, 4, 5] : [2, 3, 3, 4, 4, 5, 5]
  mood = mood_probability.sample

  # メモ（ランダムに追加）
  notes = if rand < 0.3
    sample_notes = [
      "今日は調子が良かった",
      "少し疲れを感じた",
      "ジムでトレーニング",
      "早めに就寝",
      "友人とウォーキング",
      "仕事が忙しかった",
      "リラックスできた",
      "ストレッチをしっかりやった"
    ]
    sample_notes.sample
  else
    nil
  end

  user.health_records.create!(
    recorded_at: date,
    weight: weight.round(1),
    sleep_hours: sleep_hours,
    exercise_minutes: exercise_minutes,
    steps: steps,
    heart_rate: heart_rate,
    mood: mood,
    notes: notes
  )
end

puts "✅ Created 31 health records"
puts "🎉 Seeding complete!"
puts ""
puts "📝 Test credentials:"
puts "   Email: test@example.com"
puts "   Password: password"
puts ""
puts "🚀 Start the server with: bin/dev"
puts "   Then visit: http://localhost:3000"
