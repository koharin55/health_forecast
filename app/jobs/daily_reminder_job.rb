class DailyReminderJob < ApplicationJob
  queue_as :default

  def perform
    users_without_today_record.find_each do |user|
      send_reminder(user)
    end
  end

  private

  def users_without_today_record
    users_with_today_record_ids = HealthRecord
      .where(recorded_at: Date.current)
      .select(:user_id)

    User.joins(:push_subscriptions)
        .where(push_subscriptions: { active: true })
        .where.not(id: users_with_today_record_ids)
        .distinct
  end

  def send_reminder(user)
    service = WebPushService.new
    result = service.send_reminder(user)

    Rails.logger.info(
      "[DailyReminder] User #{user.id}: " \
      "success=#{result[:success]}, " \
      "failed=#{result[:failed]}, " \
      "deactivated=#{result[:deactivated]}"
    )
  rescue StandardError => e
    Rails.logger.error("[DailyReminder] Error for user #{user.id}: #{e.message}")
  end
end
