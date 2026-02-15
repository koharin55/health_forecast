require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'is valid with location attributes' do
      user = build(:user, :with_location)
      expect(user).to be_valid
    end

    it 'validates latitude range' do
      user = build(:user, latitude: 91)
      expect(user).not_to be_valid
      expect(user.errors[:latitude]).to be_present

      user = build(:user, latitude: -91)
      expect(user).not_to be_valid
      expect(user.errors[:latitude]).to be_present
    end

    describe 'nickname' do
      it 'is valid with 20 characters' do
        user = build(:user, nickname: "あ" * 20)
        expect(user).to be_valid
      end

      it 'is invalid with 21 characters' do
        user = build(:user, nickname: "あ" * 21)
        expect(user).not_to be_valid
        expect(user.errors[:nickname]).to include("は20文字以内で入力してください")
      end

      it 'is valid with nil nickname (existing users)' do
        user = build(:user, :without_nickname)
        expect(user).to be_valid
      end

      it 'is invalid with only half-width spaces' do
        user = build(:user, nickname: "   ")
        expect(user).not_to be_valid
        expect(user.errors[:nickname]).to include("にスペースのみは使用できません")
      end

      it 'is invalid with only full-width spaces' do
        user = build(:user, nickname: "\u3000\u3000")
        expect(user).not_to be_valid
        expect(user.errors[:nickname]).to include("にスペースのみは使用できません")
      end

      it 'is invalid with mixed whitespace only' do
        user = build(:user, nickname: " \u3000 ")
        expect(user).not_to be_valid
        expect(user.errors[:nickname]).to include("にスペースのみは使用できません")
      end

      it 'is valid with spaces around text' do
        user = build(:user, nickname: " テスト ")
        expect(user).to be_valid
      end
    end

    it 'validates longitude range' do
      user = build(:user, longitude: 181)
      expect(user).not_to be_valid
      expect(user.errors[:longitude]).to be_present

      user = build(:user, longitude: -181)
      expect(user).not_to be_valid
      expect(user.errors[:longitude]).to be_present
    end
  end

  describe '#location_configured?' do
    it 'returns true when latitude and longitude are set' do
      user = build(:user, :with_location)
      expect(user.location_configured?).to be true
    end

    it 'returns false when latitude is missing' do
      user = build(:user, latitude: nil, longitude: 139.6917)
      expect(user.location_configured?).to be false
    end

    it 'returns false when longitude is missing' do
      user = build(:user, latitude: 35.6895, longitude: nil)
      expect(user.location_configured?).to be false
    end

    it 'returns false when both are missing' do
      user = build(:user)
      expect(user.location_configured?).to be false
    end
  end

  describe '#set_location_from_prefecture' do
    let(:user) { build(:user) }

    it 'sets location from valid prefecture code' do
      result = user.set_location_from_prefecture("13")

      expect(result).to be true
      expect(user.latitude).to eq(35.6895)
      expect(user.longitude).to eq(139.6917)
      expect(user.location_name).to eq("東京都")
    end

    it 'returns false for invalid prefecture code' do
      result = user.set_location_from_prefecture("99")

      expect(result).to be false
      expect(user.latitude).to be_nil
    end
  end

  describe '#set_location_from_zipcode' do
    let(:user) { build(:user) }

    context 'with valid zipcode' do
      let(:api_response) do
        {
          "message" => nil,
          "results" => [
            {
              "address1" => "東京都",
              "address2" => "新宿区",
              "address3" => "西新宿",
              "prefcode" => "13",
              "zipcode" => "1600023"
            }
          ],
          "status" => 200
        }
      end

      before do
        stub_request(:get, /zipcloud\.ibsnet\.co\.jp/)
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'sets location from zipcode' do
        result = user.set_location_from_zipcode("160-0023")

        expect(result).to be true
        expect(user.latitude).to be_present
        expect(user.longitude).to be_present
        expect(user.location_name).to eq("東京都新宿区西新宿")
      end
    end

    context 'with invalid zipcode' do
      before do
        stub_request(:get, /zipcloud\.ibsnet\.co\.jp/)
          .to_return(status: 200, body: { status: 200, results: nil }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns false and adds error' do
        result = user.set_location_from_zipcode("0000000")

        expect(result).to be false
        expect(user.errors[:base]).to be_present
      end
    end
  end

  describe '.prefecture_options' do
    it 'returns array of prefecture options' do
      options = described_class.prefecture_options

      expect(options).to be_an(Array)
      expect(options.length).to eq(47)
      expect(options.first).to eq([ "北海道", "01" ])
      expect(options.last).to eq([ "沖縄県", "47" ])
    end
  end

  describe '#time_based_greeting' do
    include ActiveSupport::Testing::TimeHelpers

    let(:user) { build(:user) }

    it 'returns おはようございます in the morning (5-11)' do
      travel_to Time.zone.local(2026, 1, 1, 8, 0, 0) do
        expect(user.time_based_greeting).to eq("おはようございます")
      end
    end

    it 'returns こんにちは in the afternoon (12-17)' do
      travel_to Time.zone.local(2026, 1, 1, 14, 0, 0) do
        expect(user.time_based_greeting).to eq("こんにちは")
      end
    end

    it 'returns こんばんは in the evening (18-4)' do
      travel_to Time.zone.local(2026, 1, 1, 21, 0, 0) do
        expect(user.time_based_greeting).to eq("こんばんは")
      end
    end
  end

  describe '#nickname_set?' do
    it 'returns true when nickname is present' do
      user = build(:user, nickname: "テスト")
      expect(user.nickname_set?).to be true
    end

    it 'returns false when nickname is nil' do
      user = build(:user, :without_nickname)
      expect(user.nickname_set?).to be false
    end

    it 'returns false when nickname is empty string' do
      user = build(:user, nickname: "")
      expect(user.nickname_set?).to be false
    end
  end

  describe '.find_prefecture' do
    it 'finds prefecture by code' do
      prefecture = described_class.find_prefecture("13")

      expect(prefecture[:name]).to eq("東京都")
      expect(prefecture[:latitude]).to eq(35.6895)
      expect(prefecture[:longitude]).to eq(139.6917)
    end

    it 'finds prefecture by numeric code' do
      prefecture = described_class.find_prefecture(13)

      expect(prefecture[:name]).to eq("東京都")
    end

    it 'returns nil for invalid code' do
      prefecture = described_class.find_prefecture("99")

      expect(prefecture).to be_nil
    end
  end

  describe '#generate_api_token!' do
    let(:user) { create(:user) }

    it 'returns a raw token and stores digest' do
      raw_token = user.generate_api_token!
      expect(raw_token).to be_present
      expect(raw_token.length).to eq(64)
      expect(user.reload.api_token_digest).to eq(Digest::SHA256.hexdigest(raw_token))
    end

    it 'generates a different token each time' do
      token1 = user.generate_api_token!
      token2 = user.generate_api_token!
      expect(token1).not_to eq(token2)
    end
  end

  describe '#revoke_api_token!' do
    let(:user) { create(:user, :with_api_token) }

    it 'sets api_token_digest to nil' do
      expect(user.api_token_digest).to be_present
      user.revoke_api_token!
      expect(user.reload.api_token_digest).to be_nil
    end
  end

  describe '#api_token_set?' do
    it 'returns true when api_token_digest is present' do
      user = create(:user, :with_api_token)
      expect(user.api_token_set?).to be true
    end

    it 'returns false when api_token_digest is nil' do
      user = create(:user)
      expect(user.api_token_set?).to be false
    end
  end

  describe '.find_by_api_token' do
    let(:user) { create(:user) }

    it 'finds user by raw token' do
      raw_token = user.generate_api_token!
      found = User.find_by_api_token(raw_token)
      expect(found).to eq(user)
    end

    it 'returns nil for invalid token' do
      user.generate_api_token!
      expect(User.find_by_api_token('invalid_token')).to be_nil
    end

    it 'returns nil for blank token' do
      expect(User.find_by_api_token(nil)).to be_nil
      expect(User.find_by_api_token('')).to be_nil
    end
  end
end
