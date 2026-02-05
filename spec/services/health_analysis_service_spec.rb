require 'rails_helper'

RSpec.describe HealthAnalysisService do
  let(:user) { create(:user, :with_location) }
  let(:service) { described_class.new(user) }

  describe '#sufficient_data?' do
    context 'when user has less than 10 records with weather and mood' do
      before do
        5.times do |i|
          create(:health_record, :with_weather, user: user, recorded_at: i.days.ago, mood: rand(1..5))
        end
      end

      it 'returns false' do
        expect(service.sufficient_data?).to be false
      end
    end

    context 'when user has 10 or more records with weather and mood' do
      before do
        12.times do |i|
          create(:health_record, :with_weather, user: user, recorded_at: i.days.ago, mood: rand(1..5))
        end
      end

      it 'returns true' do
        expect(service.sufficient_data?).to be true
      end
    end

    context 'when records have weather but no mood' do
      before do
        12.times do |i|
          create(:health_record, :with_weather, user: user, recorded_at: i.days.ago, mood: nil)
        end
      end

      it 'returns false' do
        expect(service.sufficient_data?).to be false
      end
    end
  end

  describe '#data_progress' do
    context 'when user has no records' do
      it 'returns 0' do
        expect(service.data_progress).to eq(0)
      end
    end

    context 'when user has 5 records' do
      before do
        5.times do |i|
          create(:health_record, :with_weather, user: user, recorded_at: i.days.ago, mood: 3)
        end
      end

      it 'returns 50' do
        expect(service.data_progress).to eq(50)
      end
    end

    context 'when user has 15 records' do
      before do
        15.times do |i|
          create(:health_record, :with_weather, user: user, recorded_at: i.days.ago, mood: 3)
        end
      end

      it 'returns 100 (capped)' do
        expect(service.data_progress).to eq(100)
      end
    end
  end

  describe '#analyze_weather_sensitivity' do
    context 'when insufficient data' do
      before do
        5.times do |i|
          create(:health_record, :with_weather, user: user, recorded_at: i.days.ago, mood: 3)
        end
      end

      it 'raises InsufficientDataError' do
        expect { service.analyze_weather_sensitivity }.to raise_error(
          HealthAnalysisService::InsufficientDataError,
          "分析には10件以上のデータが必要です"
        )
      end
    end

    context 'when sufficient data exists' do
      before do
        # 低気圧時は体調悪い
        5.times do |i|
          create(:health_record, user: user, recorded_at: i.days.ago, mood: 2,
                 weather_code: 61, weather_pressure: 995.0, weather_temperature: 15.0, weather_humidity: 80)
        end
        # 高気圧時は体調良い
        5.times do |i|
          create(:health_record, user: user, recorded_at: (i + 10).days.ago, mood: 4,
                 weather_code: 0, weather_pressure: 1020.0, weather_temperature: 20.0, weather_humidity: 50)
        end
      end

      it 'returns analysis result' do
        result = service.analyze_weather_sensitivity

        expect(result).to include(:sensitivity_score, :pressure_correlation, :mood_by_pressure, :data_count)
        expect(result[:data_count]).to eq(10)
      end

      it 'calculates sensitivity_score based on mood difference' do
        result = service.analyze_weather_sensitivity

        # 高気圧時(4) - 低気圧時(2) = 2の差があるので、感度は高い（50を大きく超える）
        expect(result[:sensitivity_score]).to be > 50
      end
    end
  end

  describe '#calculate_mood_by_pressure_group' do
    before do
      # 低気圧（<1000）
      create(:health_record, user: user, recorded_at: 1.day.ago, mood: 2,
             weather_code: 61, weather_pressure: 995.0, weather_temperature: 15.0, weather_humidity: 80)
      # やや低い（1000-1013）
      create(:health_record, user: user, recorded_at: 2.days.ago, mood: 3,
             weather_code: 3, weather_pressure: 1005.0, weather_temperature: 18.0, weather_humidity: 60)
      # 通常（1013-1020）
      create(:health_record, user: user, recorded_at: 3.days.ago, mood: 4,
             weather_code: 1, weather_pressure: 1015.0, weather_temperature: 20.0, weather_humidity: 50)
      # 高気圧（>=1020）
      create(:health_record, user: user, recorded_at: 4.days.ago, mood: 5,
             weather_code: 0, weather_pressure: 1025.0, weather_temperature: 22.0, weather_humidity: 45)
    end

    it 'groups mood by pressure' do
      result = service.calculate_mood_by_pressure_group

      expect(result[:low][:average]).to eq(2.0)
      expect(result[:slightly_low][:average]).to eq(3.0)
      expect(result[:normal][:average]).to eq(4.0)
      expect(result[:high][:average]).to eq(5.0)
    end
  end
end
