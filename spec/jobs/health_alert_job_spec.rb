require 'rails_helper'

RSpec.describe HealthAlertJob, type: :job do
  include ActiveJob::TestHelper

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  describe '#perform' do
    let(:user) { create(:user, :with_location) }
    let!(:push_subscription) { create(:push_subscription, user: user) }

    let(:forecast_response) do
      {
        "daily" => {
          "time" => [(Date.current + 1).to_s],
          "temperature_2m_mean" => [15.0],
          "relative_humidity_2m_mean" => [80],
          "surface_pressure_mean" => [pressure],
          "weather_code" => [61]
        }
      }
    end

    let(:current_weather_response) do
      {
        "current" => {
          "temperature_2m" => 18.0,
          "relative_humidity_2m" => 55,
          "surface_pressure" => 1015.0,
          "weather_code" => 1
        }
      }
    end

    before do
      stub_request(:get, /api\.open-meteo\.com/)
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
