require 'webpush'

class WebPushService
  class DeliveryError < StandardError; end

  def initialize
    @vapid_config = Rails.application.config.x.web_push
  end

  def send_notification(subscription, payload)
    message = build_message(payload)

    Webpush.payload_send(
      message: message.to_json,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh_key,
      auth: subscription.auth_key,
      vapid: vapid_options
    )

    subscription.touch_last_used!
    true
  rescue Webpush::ExpiredSubscription, Webpush::InvalidSubscription => e
    subscription.deactivate!
    Rails.logger.warn("[WebPush] Subscription deactivated: #{e.message}")
    false
  rescue Webpush::ResponseError => e
    Rails.logger.error("[WebPush] Delivery failed: #{e.message}")
    raise DeliveryError, e.message
  end

  def send_to_user(user, payload)
    results = { success: 0, failed: 0, deactivated: 0 }

    user.active_push_subscriptions.find_each do |subscription|
      begin
        if send_notification(subscription, payload)
          results[:success] += 1
        else
          results[:deactivated] += 1
        end
      rescue DeliveryError
        results[:failed] += 1
      end
    end

    results
  end

  def send_reminder(user)
    payload = {
      title: 'HealthForecast',
      body: '今日の健康記録をつけましょう',
      url: '/health_records/new',
      actions: [
        { action: 'record', title: '記録する' },
        { action: 'dismiss', title: '後で' }
      ]
    }

    send_to_user(user, payload)
  end

  private

  def build_message(payload)
    {
      title: payload[:title] || 'HealthForecast',
      body: payload[:body] || '',
      url: payload[:url] || '/',
      actions: payload[:actions] || []
    }
  end

  def vapid_options
    {
      subject: @vapid_config[:vapid_subject],
      public_key: @vapid_config[:vapid_public_key],
      private_key: @vapid_config[:vapid_private_key]
    }
  end
end
