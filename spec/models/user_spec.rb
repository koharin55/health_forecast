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
end
