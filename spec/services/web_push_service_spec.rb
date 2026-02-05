require 'rails_helper'

RSpec.describe WebPushService do
  let(:service) { described_class.new }
  let(:user) { create(:user) }
  let(:subscription) { create(:push_subscription, user: user) }

  describe '#send_notification' do
    let(:payload) { { title: 'Test', body: 'Test message' } }

    before do
      allow(Webpush).to receive(:payload_send)
    end

    it 'sends notification via Webpush' do
      service.send_notification(subscription, payload)

      expect(Webpush).to have_received(:payload_send).with(
        hash_including(
          endpoint: subscription.endpoint,
          p256dh: subscription.p256dh_key,
          auth: subscription.auth_key
        )
      )
    end

    it 'updates last_used_at' do
      service.send_notification(subscription, payload)
      expect(subscription.reload.last_used_at).to be_within(1.second).of(Time.current)
    end

    context 'when subscription is expired' do
      before do
        response = double('response', code: '410', body: 'Gone')
        allow(Webpush).to receive(:payload_send)
          .and_raise(Webpush::ExpiredSubscription.new(response, 'example.com'))
      end

      it 'deactivates the subscription and returns false' do
        result = service.send_notification(subscription, payload)

        expect(result).to be false
        expect(subscription.reload.active).to be false
      end
    end

    context 'when subscription is invalid' do
      before do
        response = double('response', code: '404', body: 'Not Found')
        allow(Webpush).to receive(:payload_send)
          .and_raise(Webpush::InvalidSubscription.new(response, 'example.com'))
      end

      it 'deactivates the subscription and returns false' do
        result = service.send_notification(subscription, payload)

        expect(result).to be false
        expect(subscription.reload.active).to be false
      end
    end

    context 'when there is a response error' do
      before do
        response = double('response', code: '500', body: 'Error')
        allow(Webpush).to receive(:payload_send)
          .and_raise(Webpush::ResponseError.new(response, 'example.com'))
      end

      it 'raises DeliveryError' do
        expect {
          service.send_notification(subscription, payload)
        }.to raise_error(WebPushService::DeliveryError)
      end
    end
  end

  describe '#send_to_user' do
    let(:payload) { { title: 'Test', body: 'Test message' } }

    before do
      allow(Webpush).to receive(:payload_send)
    end

    context 'with multiple active subscriptions' do
      before do
        create_list(:push_subscription, 3, user: user, active: true)
        create(:push_subscription, user: user, active: false) # inactive
      end

      it 'sends to all active subscriptions' do
        result = service.send_to_user(user, payload)

        expect(result[:success]).to eq(3)
        expect(Webpush).to have_received(:payload_send).exactly(3).times
      end
    end

    context 'when some subscriptions fail' do
      before do
        create(:push_subscription, user: user, active: true)
        create(:push_subscription, user: user, active: true)

        call_count = 0
        response = double('response', code: '410', body: 'Gone')
        allow(Webpush).to receive(:payload_send) do
          call_count += 1
          raise Webpush::ExpiredSubscription.new(response, 'example.com') if call_count == 2
        end
      end

      it 'returns correct counts' do
        result = service.send_to_user(user, payload)

        expect(result[:success]).to eq(1)
        expect(result[:deactivated]).to eq(1)
      end
    end
  end

  describe '#send_reminder' do
    before do
      create(:push_subscription, user: user, active: true)
      allow(Webpush).to receive(:payload_send)
    end

    it 'sends reminder with correct payload' do
      service.send_reminder(user)

      expect(Webpush).to have_received(:payload_send) do |args|
        message = JSON.parse(args[:message])
        expect(message['title']).to eq('PreCare')
        expect(message['body']).to include('今日の健康記録')
        expect(message['url']).to eq('/health_records/new')
      end
    end
  end
end
