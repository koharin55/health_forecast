require 'rails_helper'

RSpec.describe AiReportService do
  let(:user) { create(:user, :with_location) }
  let(:service) { described_class.new(user) }

  before do
    # Gemini API keyを設定
    allow(Rails.application.credentials).to receive(:dig).with(:gemini_api_key).and_return('test_api_key')
  end

  describe '#initialize' do
    context 'when API key is not configured' do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(:gemini_api_key).and_return(nil)
      end

      it 'raises ConfigurationError' do
        expect { described_class.new(user) }.to raise_error(
          AiReportService::ConfigurationError,
          'GEMINI_API_KEYが設定されていません'
        )
      end
    end
  end

  describe '#sufficient_data?' do
    context 'when user has less than MINIMUM_RECORDS' do
      before do
        2.times do |i|
          create(:health_record, user: user, recorded_at: i.days.ago)
        end
      end

      it 'returns false' do
        expect(service.sufficient_data?).to be false
      end
    end

    context 'when user has MINIMUM_RECORDS or more' do
      before do
        5.times do |i|
          create(:health_record, user: user, recorded_at: i.days.ago)
        end
      end

      it 'returns true' do
        expect(service.sufficient_data?).to be true
      end
    end
  end

  describe '#generate_weekly_report' do
    let(:gemini_response) do
      [
        {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  { 'text' => '## 📊 今週の振り返り\n\nテストレポート内容' }
                ]
              }
            }
          ],
          'usageMetadata' => { 'totalTokenCount' => 500 }
        }
      ]
    end

    before do
      5.times do |i|
        create(:health_record, :complete, user: user, recorded_at: i.days.ago)
      end

      # WeatherServiceのモック
      stub_request(:get, /api\.open-meteo\.com/)
        .to_return(status: 200, body: { daily: { time: [], temperature_2m_mean: [], relative_humidity_2m_mean: [], surface_pressure_mean: [], weather_code: [] } }.to_json)

      # Gemini APIのモック
      mock_client = double('Gemini')
      allow(Gemini).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:stream_generate_content).and_return(gemini_response)
    end

    it 'creates a weekly report' do
      expect { service.generate_weekly_report }.to change(WeeklyReport, :count).by(1)
    end

    it 'returns the created report' do
      report = service.generate_weekly_report

      expect(report).to be_a(WeeklyReport)
      expect(report.user).to eq(user)
      expect(report.content).to include('今週の振り返り')
    end

    it 'sets summary_data' do
      report = service.generate_weekly_report

      expect(report.summary_data).to be_present
      expect(report.summary_data['record_count']).to be_present
    end

    it 'sets tokens_used from response' do
      report = service.generate_weekly_report

      expect(report.tokens_used).to eq(500)
    end

    context 'when insufficient data' do
      before do
        user.health_records.destroy_all
      end

      it 'raises InsufficientDataError' do
        expect { service.generate_weekly_report }.to raise_error(
          AiReportService::InsufficientDataError
        )
      end
    end

    context 'when API returns error' do
      before do
        mock_client = double('Gemini')
        allow(Gemini).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:stream_generate_content).and_raise(StandardError.new('API Error'))
      end

      it 'raises ApiError' do
        expect { service.generate_weekly_report }.to raise_error(
          AiReportService::ApiError
        )
      end
    end

    context 'when report for the same week already exists' do
      before do
        create(:weekly_report, user: user, week_start: Date.current.beginning_of_week(:monday))
      end

      it 'raises ActiveRecord::RecordNotUnique' do
        expect { service.generate_weekly_report }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
