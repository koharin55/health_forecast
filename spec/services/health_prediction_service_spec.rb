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
      let(:forecast_response) do
        {
          "daily" => {
            "time" => [
              (Date.current + 1).to_s,
              (Date.current + 2).to_s,
              (Date.current + 3).to_s
            ],
            "temperature_2m_mean" => [15.0, 18.0, 20.0],
            "relative_humidity_2m_mean" => [70, 60, 50],
            "surface_pressure_mean" => [995.0, 1010.0, 1020.0],
            "weather_code" => [61, 3, 0]
          }
        }
      end

      let(:current_weather_response) do
        {
          "current" => {
            "temperature_2m" => 18.0,
            "relative_humidity_2m" => 55,
            "surface_pressure" => 1015.0,
            "weather_code" => 1
          }
        }
      end

      before do
        stub_request(:get, /api\.open-meteo\.com/)
          .with(query: hash_including("daily"))
          .to_return(status: 200, body: forecast_response.to_json, headers: { 'Content-Type' => 'application/json' })

        stub_request(:get, /api\.open-meteo\.com/)
          .with(query: hash_including("current"))
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
        stub_request(:get, /api\.open-meteo\.com/)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'returns empty array' do
        expect(service.predict_next_days).to eq([])
      end
    end
  end

  describe '#predict_for_date' do
    let(:forecast_response) do
      {
        "daily" => {
          "time" => [(Date.current + 1).to_s],
          "temperature_2m_mean" => [15.0],
          "relative_humidity_2m_mean" => [70],
          "surface_pressure_mean" => [995.0],
          "weather_code" => [61]
        }
      }
    end

    let(:current_weather_response) do
      {
        "current" => {
          "temperature_2m" => 18.0,
          "relative_humidity_2m" => 55,
          "surface_pressure" => 1015.0,
          "weather_code" => 1
        }
      }
    end

    before do
      stub_request(:get, /api\.open-meteo\.com/)
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
    let(:forecast_response) do
      {
        "daily" => {
          "time" => [(Date.current + 1).to_s],
          "temperature_2m_mean" => [temp],
          "relative_humidity_2m_mean" => [humidity],
          "surface_pressure_mean" => [pressure],
          "weather_code" => [weather_code]
        }
      }
    end

    let(:current_weather_response) do
      {
        "current" => {
          "temperature_2m" => 18.0,
          "relative_humidity_2m" => 55,
          "surface_pressure" => 1015.0,
          "weather_code" => 1
        }
      }
    end

    before do
      stub_request(:get, /api\.open-meteo\.com/)
        .to_return(status: 200, body: forecast_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    context 'with very low pressure' do
      let(:temp) { 15.0 }
      let(:humidity) { 80 }
      let(:pressure) { 985.0 }
      let(:weather_code) { 95 }

      it 'returns high or critical risk level' do
        prediction = service.predict_for_date(Date.tomorrow)

        expect([:high, :critical]).to include(prediction[:risk_level])
      end
    end

    context 'with high pressure' do
      let(:temp) { 22.0 }
      let(:humidity) { 45 }
      let(:pressure) { 1025.0 }
      let(:weather_code) { 0 }

      it 'returns low risk level' do
        prediction = service.predict_for_date(Date.tomorrow)

        expect(prediction[:risk_level]).to eq(:low)
      end
    end
  end
end
