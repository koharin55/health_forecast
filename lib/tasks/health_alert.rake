# frozen_string_literal: true

namespace :health_alert do
  desc "体調アラート通知を送信（リスクレベル高以上のユーザーに通知）"
  task send: :environment do
    Rails.logger.info("[health_alert:send] Starting health alert job...")
    HealthAlertJob.perform_now
    Rails.logger.info("[health_alert:send] Completed.")
  end
end
