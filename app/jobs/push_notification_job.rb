class PushNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id, payload)
    user = User.find_by(id: user_id)
    return unless user

    service = WebPushService.new
    result = service.send_to_user(user, payload.symbolize_keys)

    Rails.logger.info(
      "[PushNotification] User #{user_id}: " \
      "success=#{result[:success]}, " \
      "failed=#{result[:failed]}, " \
      "deactivated=#{result[:deactivated]}"
    )
  rescue StandardError => e
    Rails.logger.error("[PushNotification] Error for user #{user_id}: #{e.message}")
  end
end
