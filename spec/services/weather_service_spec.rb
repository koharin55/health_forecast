require 'rails_helper'

RSpec.describe WeatherService do
  let(:latitude) { 35.6895 }
  let(:longitude) { 139.6917 }
  let(:service) { described_class.new(latitude: latitude, longitude: longitude) }

  describe '#fetch_current_weather' do
    context 'when API returns valid response' do
      let(:api_response) do
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
          .to_return(status: 200, body: api_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns weather data hash' do
        result = service.fetch_current_weather

        expect(result[:temperature]).to eq(8.5)
        expect(result[:humidity]).to eq(45)
        expect(result[:pressure]).to eq(1013.2)
        expect(result[:weather_code]).to eq(1)
        expect(result[:weather_description]).to eq("晴れ")
        expect(result[:fetched_at]).to be_present
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, /api\.open-meteo\.com/)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises ApiError' do
        expect { service.fetch_current_weather }.to raise_error(WeatherService::ApiError)
      end
    end

    context 'when API times out' do
      before do
        stub_request(:get, /api\.open-meteo\.com/)
          .to_timeout
      end

      it 'raises TimeoutError' do
        expect { service.fetch_current_weather }.to raise_error(WeatherService::TimeoutError)
      end
    end
  end

  describe '.weather_description' do
    it 'returns description for known weather codes' do
      expect(described_class.weather_description(0)).to eq("快晴")
      expect(described_class.weather_description(1)).to eq("晴れ")
      expect(described_class.weather_description(3)).to eq("曇り")
      expect(described_class.weather_description(61)).to eq("弱い雨")
      expect(described_class.weather_description(71)).to eq("弱い雪")
      expect(described_class.weather_description(95)).to eq("雷雨")
    end

    it 'returns "不明" for unknown weather codes' do
      expect(described_class.weather_description(999)).to eq("不明")
    end
  end

  describe '.weather_icon' do
    it 'returns emoji for known weather codes' do
      expect(described_class.weather_icon(0)).to eq("☀️")
      expect(described_class.weather_icon(1)).to eq("🌤️")
      expect(described_class.weather_icon(3)).to eq("☁️")
      expect(described_class.weather_icon(45)).to eq("🌫️")
      expect(described_class.weather_icon(61)).to eq("🌧️")
      expect(described_class.weather_icon(71)).to eq("❄️")
      expect(described_class.weather_icon(95)).to eq("⛈️")
    end

    it 'returns default icon for unknown weather codes' do
      expect(described_class.weather_icon(999)).to eq("🌡️")
    end
  end
end
