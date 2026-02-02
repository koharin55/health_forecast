require 'rails_helper'

RSpec.describe PushSubscription, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:push_subscription) }

    it { is_expected.to validate_presence_of(:endpoint) }
    it { is_expected.to validate_uniqueness_of(:endpoint) }
    it { is_expected.to validate_presence_of(:p256dh_key) }
    it { is_expected.to validate_presence_of(:auth_key) }
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_subscription) { create(:push_subscription, active: true) }
      let!(:inactive_subscription) { create(:push_subscription, active: false) }

      it 'returns only active subscriptions' do
        expect(described_class.active).to include(active_subscription)
        expect(described_class.active).not_to include(inactive_subscription)
      end
    end
  end

  describe '#touch_last_used!' do
    let(:subscription) { create(:push_subscription, last_used_at: nil) }

    it 'updates last_used_at to current time' do
      expect { subscription.touch_last_used! }
        .to change { subscription.reload.last_used_at }.from(nil)

      expect(subscription.reload.last_used_at).to be_within(1.second).of(Time.current)
    end
  end

  describe '#deactivate!' do
    let(:subscription) { create(:push_subscription, active: true) }

    it 'sets active to false' do
      subscription.deactivate!
      expect(subscription.reload.active).to be false
    end
  end

  describe '#to_webpush_hash' do
    let(:subscription) do
      build(:push_subscription,
            endpoint: 'https://push.example.com/test',
            p256dh_key: 'test_p256dh',
            auth_key: 'test_auth')
    end

    it 'returns hash with endpoint and keys' do
      result = subscription.to_webpush_hash

      expect(result[:endpoint]).to eq('https://push.example.com/test')
      expect(result[:keys][:p256dh]).to eq('test_p256dh')
      expect(result[:keys][:auth]).to eq('test_auth')
    end
  end
end
