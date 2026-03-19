require 'rails_helper'

RSpec.describe WeatherService do
  let(:latitude) { 35.6895 }
  let(:longitude) { 139.6917 }
  let(:service) { described_class.new(latitude: latitude, longitude: longitude) }

  before do
    allow_any_instance_of(described_class).to receive(:owm_api_key).and_return("test_api_key")
  end

  # OWM /weather レスポンス形式
  def owm_current_response(temp: 8.5, humidity: 45, pressure: 1013.2, owm_code: 801)
    { "main" => { "temp" => temp, "humidity" => humidity, "pressure" => pressure },
      "weather" => [{ "id" => owm_code }] }
  end

  # OWM /forecast レスポンス形式（3時間刻みのリスト）
  def owm_forecast_entry(date, temp:, humidity:, pressure:, owm_code:, hour: 12)
    ts = Time.zone.parse("#{date} #{hour.to_s.rjust(2, '0')}:00:00").to_i
    { "dt" => ts, "main" => { "temp" => temp, "humidity" => humidity, "pressure" => pressure },
      "weather" => [{ "id" => owm_code }] }
  end

  describe '#fetch_current_weather' do
    context 'when API returns valid response' do
      before do
        stub_request(:get, /api\.openweathermap\.org/)
          .to_return(status: 200, body: owm_current_response.to_json,
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns weather data hash' do
        result = service.fetch_current_weather

        expect(result[:temperature]).to eq(8.5)
        expect(result[:humidity]).to eq(45)
        expect(result[:pressure]).to eq(1013.2)
        expect(result[:weather_code]).to eq(1)   # OWM 801 → WMO 1
        expect(result[:weather_description]).to eq("晴れ")
        expect(result[:fetched_at]).to be_present
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, /api\.openweathermap\.org/)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'returns nil when both current and daily fallback endpoints fail' do
        expect(service.fetch_current_weather).to be_nil
      end
    end

    context 'when API times out' do
      before do
        stub_request(:get, /api\.openweathermap\.org/)
          .to_timeout
      end

      it 'returns nil when both current and daily fallback endpoints fail' do
        expect(service.fetch_current_weather).to be_nil
      end
    end

    context 'when API returns 429 rate limit' do
      before do
        stub_request(:get, /api\.openweathermap\.org/)
          .to_return(status: 429, body: 'Too Many Requests')
      end

      it 'returns nil when both endpoints are rate limited' do
        expect(service.fetch_current_weather).to be_nil
      end

      it 'writes error cache with RATE_LIMIT_BACKOFF_TTL for current endpoint' do
        allow(Rails.cache).to receive(:write).and_call_original
        service.fetch_current_weather
        expect(Rails.cache).to have_received(:write)
          .with("weather_service/error/current/#{latitude}/#{longitude}", true,
                expires_in: WeatherService::RATE_LIMIT_BACKOFF_TTL)
      end
    end

    context 'when current endpoint returns no data but daily fallback succeeds' do
      let(:fallback_entry) do
        owm_forecast_entry(Date.current, temp: 18.0, humidity: 55, pressure: 1013.0, owm_code: 801)
      end
      let(:daily_fallback_response) { { "list" => [fallback_entry] } }

      before do
        # 1回目（/weather）は 500 エラー、2回目（/forecast）は正常
        stub_request(:get, /api\.openweathermap\.org/)
          .to_return(status: 500, body: 'Internal Server Error').then
          .to_return(status: 200, body: daily_fallback_response.to_json,
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns daily weather data as fallback' do
        result = service.fetch_current_weather
        expect(result).not_to be_nil
        expect(result[:temperature]).to eq(18.0)
        expect(result[:weather_code]).to eq(1)  # OWM 801 → WMO 1
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
        stub_request(:get, /api\.openweathermap\.org/)
          .to_return(
            status: 200,
            body: owm_current_response(temp: 15.0, humidity: 60, pressure: 1010.0, owm_code: 800).to_json,
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
        stub_request(:get, /api\.openweathermap\.org/)
          .to_return(
            status: 200,
            body: owm_current_response(temp: 15.0, humidity: 60, pressure: 1010.0, owm_code: 800).to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'is not blocked and returns weather data' do
        expect(service.fetch_current_weather).not_to be_nil
      end
    end

    context 'when current weather error cache exists' do
      let(:fallback_entry) do
        owm_forecast_entry(Date.current, temp: 20.0, humidity: 65, pressure: 1008.0, owm_code: 804)
      end
      let(:daily_fallback_response) { { "list" => [fallback_entry] } }

      before do
        allow(Rails.cache).to receive(:exist?).and_return(false)
        allow(Rails.cache).to receive(:exist?)
          .with("weather_service/error/current/#{latitude}/#{longitude}")
          .and_return(true)
        stub_request(:get, /api\.openweathermap\.org/)
          .to_return(status: 200, body: daily_fallback_response.to_json,
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'skips current endpoint and returns daily fallback data' do
        result = service.fetch_current_weather
        expect(result).not_to be_nil
        expect(result[:weather_code]).to eq(3)  # OWM 804 → WMO 3
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
        expect(a_request(:get, /api\.openweathermap\.org/)).not_to have_been_made
      end
    end
  end

  describe '#fetch_weather_for_date' do
    context 'when date is today' do
      before do
        stub_request(:get, /api\.openweathermap\.org/)
          .to_return(status: 200,
                     body: owm_current_response(temp: 12.0, humidity: 55, pressure: 1015.0, owm_code: 804).to_json,
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'fetches current weather' do
        result = service.fetch_weather_for_date(Date.current)
        expect(result[:temperature]).to eq(12.0)
      end
    end

    context 'when date is in the future' do
      let(:future_date) { Date.current + 1 }
      let(:forecast_entry) do
        owm_forecast_entry(future_date, temp: 10.0, humidity: 50, pressure: 1012.0, owm_code: 801)
      end

      before do
        stub_request(:get, /api\.openweathermap\.org/)
          .to_return(status: 200, body: { "list" => [forecast_entry] }.to_json,
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'fetches forecast weather' do
        result = service.fetch_weather_for_date(future_date)
        expect(result[:weather_code]).to eq(1)  # OWM 801 → WMO 1
      end
    end

    context 'when date is in the past' do
      let(:archive_response) do
        { "daily" => { "time" => [(Date.current - 1).to_s], "temperature_2m_mean" => [10.0],
                       "relative_humidity_2m_mean" => [50], "surface_pressure_mean" => [1012.0],
                       "weather_code" => [1] } }
      end

      before do
        stub_request(:get, /archive-api\.open-meteo\.com/)
          .to_return(status: 200, body: archive_response.to_json,
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'fetches historical weather' do
        result = service.fetch_weather_for_date(Date.current - 1)
        expect(result[:weather_code]).to eq(1)
      end
    end
  end

  describe '#fetch_forecast_days' do
    let(:forecast_response) do
      entries = (1..3).map.with_index do |i, idx|
        owm_codes = [801, 803, 800]
        temps     = [15.0, 16.0, 14.0]
        humidities = [55, 60, 50]
        pressures  = [1010.0, 1012.0, 1015.0]
        owm_forecast_entry(Date.current + i,
                           temp: temps[idx], humidity: humidities[idx],
                           pressure: pressures[idx], owm_code: owm_codes[idx])
      end
      { "list" => entries }
    end

    context 'when API returns valid response' do
      before do
        stub_request(:get, /api\.openweathermap\.org/)
          .to_return(status: 200, body: forecast_response.to_json,
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns array of forecast weather hashes' do
        result = service.fetch_forecast_days(days: 3)
        expect(result.size).to eq(3)
        expect(result.first[:weather_code]).to eq(1)  # OWM 801 → WMO 1
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
        expect(a_request(:get, /api\.openweathermap\.org/)).not_to have_been_made
      end
    end
  end

  describe '#owm_code_to_wmo (private)' do
    subject(:convert) { service.send(:owm_code_to_wmo, owm_code) }

    context 'with clear sky (800)' do
      let(:owm_code) { 800 }
      it { is_expected.to eq(0) }
    end

    context 'with few clouds (801)' do
      let(:owm_code) { 801 }
      it { is_expected.to eq(1) }
    end

    context 'with overcast clouds (804)' do
      let(:owm_code) { 804 }
      it { is_expected.to eq(3) }
    end

    context 'with thunderstorm (200)' do
      let(:owm_code) { 200 }
      it { is_expected.to eq(95) }
    end

    context 'with rain (500)' do
      let(:owm_code) { 500 }
      it { is_expected.to eq(61) }
    end

    context 'with snow (600)' do
      let(:owm_code) { 600 }
      it { is_expected.to eq(71) }
    end

    context 'with fog (741)' do
      let(:owm_code) { 741 }
      it 'returns WMO 45 (霧) — Range 731..781 より個別マッピングが優先される' do
        is_expected.to eq(45)
      end
    end

    context 'with unknown code' do
      let(:owm_code) { 999 }
      it 'returns WMO 3 (曇り) as fallback' do
        is_expected.to eq(3)
      end
    end

    context 'with nil' do
      let(:owm_code) { nil }
      it 'returns nil' do
        is_expected.to be_nil
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
