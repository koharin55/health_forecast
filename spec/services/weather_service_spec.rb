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

      it 'returns nil when both current and daily fallback endpoints fail' do
        expect(service.fetch_current_weather).to be_nil
      end
    end

    context 'when API times out' do
      before do
        stub_request(:get, /api\.open-meteo\.com/)
          .to_timeout
      end

      it 'returns nil when both current and daily fallback endpoints fail' do
        expect(service.fetch_current_weather).to be_nil
      end
    end

    context 'when current endpoint returns no data but daily fallback succeeds' do
      let(:daily_fallback_response) do
        { "daily" => { "time" => [Date.current.to_s], "temperature_2m_mean" => [18.0],
                       "relative_humidity_2m_mean" => [55], "surface_pressure_mean" => [1013.0],
                       "weather_code" => [1] } }
      end

      before do
        # 1回目（current）は 500 エラー、2回目以降（daily fallback）は正常
        stub_request(:get, /api\.open-meteo\.com/)
          .to_return(status: 500, body: 'Internal Server Error').then
          .to_return(status: 200, body: daily_fallback_response.to_json,
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns daily weather data as fallback' do
        result = service.fetch_current_weather
        expect(result).not_to be_nil
        expect(result[:temperature]).to eq(18.0)
        expect(result[:weather_code]).to eq(1)
      end
    end

    # エラーキャッシュのキー形式は WeatherService#cache_key 参照:
    # "weather_service/error/<scope>/<latitude>/<longitude>"
    context 'when forecast_days error cache exists' do
      before do
        allow(Rails.cache).to receive(:exist?).and_return(false)
        allow(Rails.cache).to receive(:exist?)
          .with("weather_service/error/forecast_days/#{latitude}/#{longitude}")
          .and_return(true)
        # test環境はnull_storeのため、fetchブロックが毎回実行されAPIが呼ばれる
        stub_request(:get, /api\.open-meteo\.com/)
          .to_return(
            status: 200,
            body: { "current" => { "temperature_2m" => 15.0, "relative_humidity_2m" => 60,
                                   "surface_pressure" => 1010.0, "weather_code" => 0 } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'is not blocked and returns weather data' do
        expect(service.fetch_current_weather).not_to be_nil
      end
    end

    context 'when historical error cache exists' do
      before do
        allow(Rails.cache).to receive(:exist?).and_return(false)
        allow(Rails.cache).to receive(:exist?)
          .with("weather_service/error/historical/#{latitude}/#{longitude}")
          .and_return(true)
        # test環境はnull_storeのため、fetchブロックが毎回実行されAPIが呼ばれる
        stub_request(:get, /api\.open-meteo\.com/)
          .to_return(
            status: 200,
            body: { "current" => { "temperature_2m" => 15.0, "relative_humidity_2m" => 60,
                                   "surface_pressure" => 1010.0, "weather_code" => 0 } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'is not blocked and returns weather data' do
        expect(service.fetch_current_weather).not_to be_nil
      end
    end

    context 'when current weather error cache exists' do
      let(:daily_fallback_response) do
        { "daily" => { "time" => [Date.current.to_s], "temperature_2m_mean" => [20.0],
                       "relative_humidity_2m_mean" => [65], "surface_pressure_mean" => [1008.0],
                       "weather_code" => [3] } }
      end

      before do
        allow(Rails.cache).to receive(:exist?).and_return(false)
        allow(Rails.cache).to receive(:exist?)
          .with("weather_service/error/current/#{latitude}/#{longitude}")
          .and_return(true)
        stub_request(:get, /api\.open-meteo\.com/)
          .to_return(status: 200, body: daily_fallback_response.to_json,
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'skips current endpoint and returns daily fallback data' do
        result = service.fetch_current_weather
        expect(result).not_to be_nil
        expect(result[:weather_code]).to eq(3)
        expect(result[:temperature]).to eq(20.0)
      end
    end

    context 'when both current and daily fallback error caches exist' do
      before do
        allow(Rails.cache).to receive(:exist?).and_return(false)
        allow(Rails.cache).to receive(:exist?)
          .with("weather_service/error/current/#{latitude}/#{longitude}")
          .and_return(true)
        allow(Rails.cache).to receive(:exist?)
          .with("weather_service/error/current_fallback/#{latitude}/#{longitude}")
          .and_return(true)
      end

      it 'returns nil without calling the API' do
        expect(service.fetch_current_weather).to be_nil
        expect(a_request(:get, /api\.open-meteo\.com/)).not_to have_been_made
      end
    end
  end

  describe '#fetch_weather_for_date' do
    let(:current_response) do
      { "current" => { "temperature_2m" => 12.0, "relative_humidity_2m" => 55,
                       "surface_pressure" => 1015.0, "weather_code" => 3 } }
    end
    let(:daily_response) do
      { "daily" => { "time" => [Date.current.to_s], "temperature_2m_mean" => [10.0],
                     "relative_humidity_2m_mean" => [50], "surface_pressure_mean" => [1012.0],
                     "weather_code" => [1] } }
    end

    context 'when date is today' do
      it 'fetches current weather' do
        stub_request(:get, /api\.open-meteo\.com/)
          .to_return(status: 200, body: current_response.to_json,
                     headers: { 'Content-Type' => 'application/json' })
        result = service.fetch_weather_for_date(Date.current)
        expect(result[:temperature]).to eq(12.0)
      end
    end

    context 'when date is in the future' do
      it 'fetches forecast weather' do
        stub_request(:get, /api\.open-meteo\.com/)
          .to_return(status: 200, body: daily_response.to_json,
                     headers: { 'Content-Type' => 'application/json' })
        result = service.fetch_weather_for_date(Date.current + 1)
        expect(result[:weather_code]).to eq(1)
      end
    end

    context 'when date is in the past' do
      it 'fetches historical weather' do
        stub_request(:get, /api\.open-meteo\.com/)
          .to_return(status: 200, body: daily_response.to_json,
                     headers: { 'Content-Type' => 'application/json' })
        result = service.fetch_weather_for_date(Date.current - 1)
        expect(result[:weather_code]).to eq(1)
      end
    end
  end

  describe '#fetch_forecast_days' do
    let(:forecast_response) do
      dates = (1..3).map { |i| (Date.current + i).to_s }
      { "daily" => { "time" => dates, "temperature_2m_mean" => [15.0, 16.0, 14.0],
                     "relative_humidity_2m_mean" => [55, 60, 50],
                     "surface_pressure_mean" => [1010.0, 1012.0, 1015.0],
                     "weather_code" => [1, 3, 0] } }
    end

    context 'when API returns valid response' do
      before do
        stub_request(:get, /api\.open-meteo\.com/)
          .to_return(status: 200, body: forecast_response.to_json,
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns array of forecast weather hashes' do
        result = service.fetch_forecast_days(days: 3)
        expect(result.size).to eq(3)
        expect(result.first[:weather_code]).to eq(1)
        expect(result.first[:date]).to eq(Date.current + 1)
        expect(result.first[:fetched_at]).to be_present
      end
    end

    context 'when days is out of range' do
      it 'returns empty array for 0 days' do
        expect(service.fetch_forecast_days(days: 0)).to eq([])
      end

      it 'returns empty array for more than MAX_FORECAST_DAYS' do
        expect(service.fetch_forecast_days(days: WeatherService::MAX_FORECAST_DAYS + 1)).to eq([])
      end
    end

    context 'when forecast_days error cache exists' do
      before do
        allow(Rails.cache).to receive(:exist?)
          .with("weather_service/error/forecast_days/#{latitude}/#{longitude}")
          .and_return(true)
      end

      it 'returns empty array without calling the API' do
        expect(service.fetch_forecast_days(days: 3)).to eq([])
        expect(a_request(:get, /api\.open-meteo\.com/)).not_to have_been_made
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
