require 'rails_helper'

RSpec.describe HealthAlertJob, type: :job do
  include ActiveJob::TestHelper

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  describe '#perform' do
    let(:user) { create(:user, :with_location) }
    let!(:push_subscription) { create(:push_subscription, user: user) }

    # OWM /forecast list形式: Date.tomorrow 正午エントリ
    # OWM 500 → WMO 61 (弱い雨)
    let(:forecast_response) do
      ts = Time.zone.parse("#{Date.tomorrow} 12:00:00").to_i
      { "list" => [
        { "dt" => ts, "main" => { "temp" => 15.0, "humidity" => 80, "pressure" => pressure },
          "weather" => [{ "id" => 500 }] }
      ] }
    end

    before do
      allow_any_instance_of(WeatherService).to receive(:owm_api_key).and_return("test_api_key")
      stub_request(:get, /api\.openweathermap\.org/)
        .to_return(status: 200, body: forecast_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    context 'when tomorrow has high risk' do
      let(:pressure) { 985.0 }

      it 'enqueues push notification' do
        expect {
          described_class.new.perform
        }.to have_enqueued_job(PushNotificationJob).with(user.id, anything)
      end

      it 'sends notification with correct title' do
        expect {
          described_class.new.perform
        }.to have_enqueued_job(PushNotificationJob).with(
          user.id,
          hash_including(title: "PreCare - 体調予測アラート")
        )
      end
    end

    context 'when tomorrow has low risk' do
      let(:pressure) { 1025.0 }

      it 'does not enqueue push notification' do
        expect {
          described_class.new.perform
        }.not_to have_enqueued_job(PushNotificationJob)
      end
    end

    context 'when user has no push subscriptions' do
      before do
        push_subscription.destroy
      end

      let(:pressure) { 985.0 }

      it 'does not enqueue push notification' do
        expect {
          described_class.new.perform
        }.not_to have_enqueued_job(PushNotificationJob)
      end
    end

    context 'when user has no location configured' do
      let(:user) { create(:user) }
      let(:pressure) { 985.0 }

      before do
        push_subscription.update(user: user)
      end

      it 'does not enqueue push notification' do
        expect {
          described_class.new.perform
        }.not_to have_enqueued_job(PushNotificationJob)
      end
    end

    context 'with multiple users' do
      let!(:user2) { create(:user, :with_location) }
      let!(:push_subscription2) { create(:push_subscription, user: user2) }
      let(:pressure) { 985.0 }

      it 'processes all users with location' do
        expect {
          described_class.new.perform
        }.to have_enqueued_job(PushNotificationJob).at_least(2).times
      end
    end
  end
end
