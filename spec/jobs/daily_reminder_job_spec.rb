require 'rails_helper'

RSpec.describe DailyReminderJob, type: :job do
  describe '#perform' do
    let(:web_push_service) { instance_double(WebPushService) }

    before do
      allow(WebPushService).to receive(:new).and_return(web_push_service)
      allow(web_push_service).to receive(:send_reminder)
        .and_return({ success: 1, failed: 0, deactivated: 0 })
    end

    context 'when user has no record today and has active subscription' do
      let(:user) { create(:user) }

      before do
        create(:push_subscription, user: user, active: true)
      end

      it 'sends reminder to the user' do
        described_class.new.perform

        expect(web_push_service).to have_received(:send_reminder).with(user)
      end
    end

    context 'when user already has a record today' do
      let(:user) { create(:user) }

      before do
        create(:push_subscription, user: user, active: true)
        create(:health_record, user: user, recorded_at: Date.current)
      end

      it 'does not send reminder' do
        described_class.new.perform

        expect(web_push_service).not_to have_received(:send_reminder)
      end
    end

    context 'when user has no active subscription' do
      let(:user) { create(:user) }

      before do
        create(:push_subscription, user: user, active: false)
      end

      it 'does not send reminder' do
        described_class.new.perform

        expect(web_push_service).not_to have_received(:send_reminder)
      end
    end

    context 'when user has record from yesterday' do
      let(:user) { create(:user) }

      before do
        create(:push_subscription, user: user, active: true)
        create(:health_record, user: user, recorded_at: Date.yesterday)
      end

      it 'sends reminder to the user' do
        described_class.new.perform

        expect(web_push_service).to have_received(:send_reminder).with(user)
      end
    end
  end
end
