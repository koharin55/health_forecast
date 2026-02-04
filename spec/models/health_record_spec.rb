require 'rails_helper'

RSpec.describe HealthRecord, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      record = build(:health_record)
      expect(record).to be_valid
    end

    it 'is valid with weather attributes' do
      record = build(:health_record, :with_weather)
      expect(record).to be_valid
    end

    it 'validates weather_humidity range' do
      record = build(:health_record, weather_humidity: 101)
      expect(record).not_to be_valid
      expect(record.errors[:weather_humidity]).to be_present

      record = build(:health_record, weather_humidity: -1)
      expect(record).not_to be_valid
      expect(record.errors[:weather_humidity]).to be_present
    end

    it 'validates weather_pressure range' do
      record = build(:health_record, weather_pressure: 869)
      expect(record).not_to be_valid
      expect(record.errors[:weather_pressure]).to be_present

      record = build(:health_record, weather_pressure: 1085)
      expect(record).not_to be_valid
      expect(record.errors[:weather_pressure]).to be_present
    end
  end

  describe 'scopes' do
    describe '.with_weather' do
      it 'returns records with weather data' do
        create(:health_record, :with_weather)
        create(:health_record)

        expect(HealthRecord.with_weather.count).to eq(1)
      end
    end
  end

  describe '#has_weather_data?' do
    it 'returns true when weather_code is present' do
      record = build(:health_record, :with_weather)
      expect(record.has_weather_data?).to be true
    end

    it 'returns false when weather_code is nil' do
      record = build(:health_record)
      expect(record.has_weather_data?).to be false
    end
  end

  describe '#weather_icon' do
    it 'returns icon when weather_code is present' do
      record = build(:health_record, weather_code: 1)
      expect(record.weather_icon).to eq("🌤️")
    end

    it 'returns nil when weather_code is nil' do
      record = build(:health_record)
      expect(record.weather_icon).to be_nil
    end
  end

  describe '#weather_display' do
    it 'returns formatted string when weather data is present' do
      record = build(:health_record, weather_code: 1, weather_description: "晴れ")
      expect(record.weather_display).to eq("🌤️ 晴れ")
    end

    it 'returns nil when weather data is missing' do
      record = build(:health_record)
      expect(record.weather_display).to be_nil
    end
  end

  describe '#pressure_level' do
    it 'returns :low when pressure is below 1000' do
      record = build(:health_record, weather_pressure: 995)
      expect(record.pressure_level).to eq(:low)
    end

    it 'returns :slightly_low when pressure is 1000-1012' do
      record = build(:health_record, weather_pressure: 1005)
      expect(record.pressure_level).to eq(:slightly_low)
    end

    it 'returns :normal when pressure is 1013-1019' do
      record = build(:health_record, weather_pressure: 1015)
      expect(record.pressure_level).to eq(:normal)
    end

    it 'returns :high when pressure is 1020 or above' do
      record = build(:health_record, weather_pressure: 1025)
      expect(record.pressure_level).to eq(:high)
    end

    it 'returns nil when pressure is nil' do
      record = build(:health_record)
      expect(record.pressure_level).to be_nil
    end
  end

  describe '#fetch_and_set_weather!' do
    let(:user) { create(:user, :with_location) }
    let(:record) { build(:health_record, user: user, recorded_at: Date.current) }

    context 'when user has location configured' do
      let(:weather_response) do
        {
          "current" => {
            "time" => "2026-02-02T12:00",
            "temperature_2m" => 8.5,
            "relative_humidity_2m" => 45,
            "surface_pressure" => 1013.2,
            "weather_code" => 1
          }
        }
      end

      before do
        stub_request(:get, /api\.open-meteo\.com/)
          .to_return(status: 200, body: weather_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'fetches and sets weather data' do
        result = record.fetch_and_set_weather!

        expect(result).to be true
        expect(record.weather_temperature).to eq(8.5)
        expect(record.weather_humidity).to eq(45)
        expect(record.weather_pressure).to eq(1013.2)
        expect(record.weather_code).to eq(1)
        expect(record.weather_description).to eq("晴れ")
      end
    end

    context 'when user has no location configured' do
      let(:user_without_location) { create(:user) }
      let(:record) { build(:health_record, user: user_without_location) }

      it 'returns false without making API call' do
        result = record.fetch_and_set_weather!

        expect(result).to be false
        expect(record.weather_code).to be_nil
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, /api\.open-meteo\.com/)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'returns false and does not set weather data' do
        result = record.fetch_and_set_weather!

        expect(result).to be false
        expect(record.weather_code).to be_nil
      end
    end
  end
end
