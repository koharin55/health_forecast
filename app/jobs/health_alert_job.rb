# 体調アラートジョブ
# リスクレベル「高」以上のユーザーにプッシュ通知を送信
class HealthAlertJob < ApplicationJob
  queue_as :default

  # リスクレベル「高」以上で通知
  ALERT_THRESHOLD_LEVELS = %i[high critical].freeze

  def perform
    sent_count = 0
    skip_count = 0

    User.where.not(latitude: nil).find_each do |user|
      next unless user.active_push_subscriptions.exists?

      result = process_user(user)
      if result
        sent_count += 1
      else
        skip_count += 1
      end
    rescue StandardError => e
      Rails.logger.error("[HealthAlert] Error for user #{user.id}: #{e.message}")
    end

    Rails.logger.info("[HealthAlert] Completed: sent=#{sent_count}, skipped=#{skip_count}")
  end

  private

  def process_user(user)
    prediction_service = HealthPredictionService.new(user)
    predictions = prediction_service.predict_next_days(days: 1)

    return false if predictions.empty?

    tomorrow = predictions.first
    return false unless ALERT_THRESHOLD_LEVELS.include?(tomorrow[:risk_level])

    send_alert(user, tomorrow)
    true
  end

  def send_alert(user, prediction)
    payload = build_payload(prediction)

    PushNotificationJob.perform_later(
      user.id,
      payload
    )
  end

  def build_payload(prediction)
    {
      title: "PreCare - 体調予測アラート",
      body: build_alert_body(prediction),
      icon: "/icon-192.png",
      badge: "/badge-72.png",
      tag: "health-alert-#{prediction[:date]}",
      data: {
        type: "health_alert",
        date: prediction[:date].to_s,
        risk_level: prediction[:risk_level].to_s,
        risk_score: prediction[:risk_score]
      }
    }
  end

  def build_alert_body(prediction)
    date_label = prediction[:date] == Date.tomorrow ? "明日" : prediction[:date].strftime("%-m/%-d")
    risk_label = prediction[:risk_level_label]

    body = "#{date_label}は体調注意日（#{risk_label}）です。"

    if prediction[:factors].any?
      factor_text = prediction[:factors].first[:message]
      body += "#{factor_text}。"
    end

    body += prediction[:advice].truncate(50)
    body
  end
end
