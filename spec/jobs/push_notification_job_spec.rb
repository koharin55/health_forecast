require 'rails_helper'

RSpec.describe PushNotificationJob, type: :job do
  describe '#perform' do
    let(:user) { create(:user) }
    let(:payload) { { title: 'Test', body: 'Test message', url: '/' } }
    let(:web_push_service) { instance_double(WebPushService) }

    before do
      allow(WebPushService).to receive(:new).and_return(web_push_service)
      allow(web_push_service).to receive(:send_to_user)
        .and_return({ success: 1, failed: 0, deactivated: 0 })
    end

    it 'sends notification to the user' do
      described_class.new.perform(user.id, payload)

      expect(web_push_service).to have_received(:send_to_user).with(user, payload)
    end

    context 'when user does not exist' do
      it 'does not raise error' do
        expect {
          described_class.new.perform(-1, payload)
        }.not_to raise_error

        expect(web_push_service).not_to have_received(:send_to_user)
      end
    end

    context 'when payload has string keys' do
      let(:string_payload) { { 'title' => 'Test', 'body' => 'Test message' } }

      it 'symbolizes keys' do
        described_class.new.perform(user.id, string_payload)

        expect(web_push_service).to have_received(:send_to_user)
          .with(user, { title: 'Test', body: 'Test message' })
      end
    end
  end
end
