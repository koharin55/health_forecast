require 'rails_helper'

RSpec.describe HealthPredictionService do
  let(:user) { create(:user, :with_location) }
  let(:service) { described_class.new(user) }

  describe '#predict_next_days' do
    context 'when user has no location configured' do
      let(:user) { create(:user) }

      it 'returns empty array' do
        expect(service.predict_next_days).to eq([])
      end
    end

    context 'when user has location configured' do
      # OWM /forecast list形式: 各日の正午エントリ
      # Day1: temp=15.0, humidity=70, pressure=995.0, OWM500(→WMO61:弱い雨)
      # Day2: temp=18.0, humidity=60, pressure=1010.0, OWM804(→WMO3:曇り)
      # Day3: temp=20.0, humidity=50, pressure=1020.0, OWM800(→WMO0:快晴)
      let(:forecast_response) do
        entries = [
          [Date.current + 1, 15.0, 70, 995.0, 500],
          [Date.current + 2, 18.0, 60, 1010.0, 804],
          [Date.current + 3, 20.0, 50, 1020.0, 800]
        ].map do |date, temp, humidity, pressure, owm_code|
          ts = Time.zone.parse("#{date} 12:00:00").to_i
          { "dt" => ts, "main" => { "temp" => temp, "humidity" => humidity, "pressure" => pressure },
            "weather" => [{ "id" => owm_code }] }
        end
        { "list" => entries }
      end

      let(:current_weather_response) do
        # OWM /weather 形式: OWM 801 → WMO 1 (晴れ)
        { "main" => { "temp" => 18.0, "humidity" => 55, "pressure" => 1015.0 },
          "weather" => [{ "id" => 801 }] }
      end

      before do
        allow_any_instance_of(WeatherService).to receive(:owm_api_key).and_return("test_api_key")
        # /forecast も /weather も同じホスト。fetch_forecast_daysは/forecast、fetch_current_weatherは/weather
        stub_request(:get, /api\.openweathermap\.org\/data\/2\.5\/forecast/)
          .to_return(status: 200, body: forecast_response.to_json, headers: { 'Content-Type' => 'application/json' })

        stub_request(:get, /api\.openweathermap\.org\/data\/2\.5\/weather/)
          .to_return(status: 200, body: current_weather_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns predictions for 3 days' do
        predictions = service.predict_next_days(days: 3)

        expect(predictions.size).to eq(3)
      end

      it 'returns prediction with expected keys' do
        predictions = service.predict_next_days(days: 3)
        prediction = predictions.first

        expect(prediction).to include(
          :date,
          :risk_score,
          :risk_level,
          :risk_level_label,
          :risk_level_icon,
          :factors,
          :advice,
          :forecast
        )
      end

      it 'calculates higher risk for low pressure' do
        predictions = service.predict_next_days(days: 3)

        # 最初の日（低気圧995hPa）は高リスク
        low_pressure_prediction = predictions.first
        # 最後の日（高気圧1020hPa）は低リスク
        high_pressure_prediction = predictions.last

        expect(low_pressure_prediction[:risk_score]).to be > high_pressure_prediction[:risk_score]
      end

      it 'identifies low pressure as risk factor' do
        predictions = service.predict_next_days(days: 3)
        low_pressure_prediction = predictions.first

        factor_types = low_pressure_prediction[:factors].map { |f| f[:type] }
        expect(factor_types).to include(:low_pressure)
      end
    end

    context 'when API returns error' do
      before do
        allow_any_instance_of(WeatherService).to receive(:owm_api_key).and_return("test_api_key")
        stub_request(:get, /api\.openweathermap\.org/)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'returns empty array' do
        expect(service.predict_next_days).to eq([])
      end
    end
  end

  describe '#predict_for_date' do
    # OWM /forecast list形式: Date.tomorrow 正午エントリ
    # OWM 500 → WMO 61 (弱い雨)
    let(:forecast_response) do
      ts = Time.zone.parse("#{Date.tomorrow} 12:00:00").to_i
      { "list" => [
        { "dt" => ts, "main" => { "temp" => 15.0, "humidity" => 70, "pressure" => 995.0 },
          "weather" => [{ "id" => 500 }] }
      ] }
    end

    before do
      allow_any_instance_of(WeatherService).to receive(:owm_api_key).and_return("test_api_key")
      stub_request(:get, /api\.openweathermap\.org/)
        .to_return(status: 200, body: forecast_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns prediction for specific date' do
      prediction = service.predict_for_date(Date.tomorrow)

      expect(prediction).not_to be_nil
      expect(prediction[:date]).to eq(Date.tomorrow)
    end
  end

  describe '#sufficient_analysis_data?' do
    context 'when user has insufficient data' do
      it 'returns false' do
        expect(service.sufficient_analysis_data?).to be false
      end
    end

    context 'when user has sufficient data' do
      before do
        12.times do |i|
          create(:health_record, :with_weather, user: user, recorded_at: i.days.ago, mood: rand(1..5))
        end
      end

      it 'returns true' do
        expect(service.sufficient_analysis_data?).to be true
      end
    end
  end

  describe 'risk level determination' do
    # OWM /forecast list形式: Date.tomorrow 正午エントリ
    let(:forecast_response) do
      ts = Time.zone.parse("#{Date.tomorrow} 12:00:00").to_i
      { "list" => [
        { "dt" => ts, "main" => { "temp" => temp, "humidity" => humidity, "pressure" => pressure },
          "weather" => [{ "id" => owm_code }] }
      ] }
    end

    before do
      allow_any_instance_of(WeatherService).to receive(:owm_api_key).and_return("test_api_key")
      stub_request(:get, /api\.openweathermap\.org/)
        .to_return(status: 200, body: forecast_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    context 'with very low pressure' do
      let(:temp) { 15.0 }
      let(:humidity) { 80 }
      let(:pressure) { 985.0 }
      let(:owm_code) { 200 }   # 雷雨 → WMO 95

      it 'returns high or critical risk level' do
        prediction = service.predict_for_date(Date.tomorrow)

        expect([:high, :critical]).to include(prediction[:risk_level])
      end
    end

    context 'with high pressure' do
      let(:temp) { 22.0 }
      let(:humidity) { 45 }
      let(:pressure) { 1025.0 }
      let(:owm_code) { 800 }   # 快晴 → WMO 0

      it 'returns low risk level' do
        prediction = service.predict_for_date(Date.tomorrow)

        expect(prediction[:risk_level]).to eq(:low)
      end
    end
  end
end
