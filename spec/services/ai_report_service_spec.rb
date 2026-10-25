require 'rails_helper'

RSpec.describe AiReportService do
  let(:user) { create(:user, :with_location) }
  let(:service) { described_class.new(user) }

  before do
    # Gemini API keyを設定
    allow(Rails.application.credentials).to receive(:dig).with(:gemini_api_key).and_return('test_api_key')
  end

  describe 'Gemini client configuration' do
    it 'passes GEMINI_MODEL with non-streaming mode to the Gemini client' do
      allow(Gemini).to receive(:new).and_return(instance_double(Gemini::Controllers::Client))

      service.send(:client)

      expect(Gemini).to have_received(:new).with(
        hash_including(
          options: hash_including(model: described_class::GEMINI_MODEL, server_sent_events: false)
        )
      )
    end

    it 'sets request timeouts on the Gemini client' do
      allow(Gemini).to receive(:new).and_return(instance_double(Gemini::Controllers::Client))

      service.send(:client)

      expect(Gemini).to have_received(:new).with(
        hash_including(
          options: hash_including(
            connection: {
              request: {
                timeout: described_class::REQUEST_TIMEOUT_SECONDS,
                open_timeout: described_class::OPEN_TIMEOUT_SECONDS
              }
            }
          )
        )
      )
    end
  end

  describe '#initialize' do
    context 'when API key is not configured' do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(:gemini_api_key).and_return(nil)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return(nil)
      end

      it 'raises ConfigurationError' do
        expect { described_class.new(user) }.to raise_error(
          AiReportService::ConfigurationError,
          'GEMINI_API_KEYが設定されていません'
        )
      end
    end
  end

  describe '#check_sufficient_data' do
    let(:week_start) { Date.current - AiReportService::DEFAULT_PERIOD_DAYS }
    let(:week_end) { Date.current - 1 }

    context 'when period has less than MINIMUM_PERIOD_RECORDS' do
      before do
        2.times do |i|
          create(:health_record, user: user, recorded_at: Date.current - 1 - i)
        end
      end

      it 'returns sufficient: false with count' do
        result = service.check_sufficient_data(week_start, week_end)
        expect(result[:sufficient]).to be false
        expect(result[:count]).to eq(2)
        expect(result[:required]).to eq(AiReportService::MINIMUM_PERIOD_RECORDS)
      end
    end

    context 'when period has MINIMUM_PERIOD_RECORDS or more' do
      before do
        5.times do |i|
          create(:health_record, user: user, recorded_at: Date.current - 1 - i)
        end
      end

      it 'returns sufficient: true with count' do
        result = service.check_sufficient_data(week_start, week_end)
        expect(result[:sufficient]).to be true
        expect(result[:count]).to eq(5)
      end
    end

    context 'when records exist outside the period' do
      before do
        # 対象期間外に5件作成
        5.times do |i|
          create(:health_record, user: user, recorded_at: Date.current - 30 - i)
        end
        # 対象期間内に1件のみ
        create(:health_record, user: user, recorded_at: Date.current - 1)
      end

      it 'returns sufficient: false because only period records are counted' do
        result = service.check_sufficient_data(week_start, week_end)
        expect(result[:sufficient]).to be false
        expect(result[:count]).to eq(1)
      end
    end

    context 'when called without arguments uses default period' do
      before do
        5.times do |i|
          create(:health_record, user: user, recorded_at: Date.current - 1 - i)
        end
      end

      it 'returns sufficient: true' do
        result = service.check_sufficient_data
        expect(result[:sufficient]).to be true
      end
    end
  end

  describe '#validate_period' do
    it 'returns nil for valid period' do
      result = service.validate_period(Date.current - 7, Date.current - 1)
      expect(result).to be_nil
    end

    it 'returns error when end is before start' do
      result = service.validate_period(Date.current - 1, Date.current - 7)
      expect(result).to include('終了日は開始日より後')
    end

    it 'returns error when start is in the future' do
      result = service.validate_period(Date.current + 1, Date.current + 3)
      expect(result).to include('未来の日付')
    end

    it 'returns error when end is in the future' do
      result = service.validate_period(Date.current - 3, Date.current + 1)
      expect(result).to include('未来の日付')
    end

    it 'returns error when period exceeds MAX_PERIOD_DAYS' do
      result = service.validate_period(Date.current - 40, Date.current - 1)
      expect(result).to include("最大#{AiReportService::MAX_PERIOD_DAYS}日間")
    end

    it 'returns nil for exactly MAX_PERIOD_DAYS period' do
      result = service.validate_period(Date.current - AiReportService::MAX_PERIOD_DAYS, Date.current - 1)
      expect(result).to be_nil
    end
  end

  describe '#generate_weekly_report' do
    let(:gemini_response) do
      {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'text' => '## 📊 今週の振り返り\n\nテストレポート内容' }
              ]
            },
            'finishReason' => 'STOP'
          }
        ],
        'usageMetadata' => { 'totalTokenCount' => 500 }
      }
    end

    before do
      # 対象期間（昨日〜7日前）内にレコードを作成
      5.times do |i|
        create(:health_record, :complete, user: user, recorded_at: Date.current - 1 - i)
      end

      # WeatherServiceのモック（天気予報: OpenWeatherMap）
      stub_request(:get, /api\.openweathermap\.org/)
        .to_return(status: 200, body: { list: [] }.to_json)

      # WeatherServiceのモック（過去データ: Open-Meteo）
      stub_request(:get, /api\.open-meteo\.com/)
        .to_return(status: 200, body: { daily: { time: [], temperature_2m_mean: [], relative_humidity_2m_mean: [], surface_pressure_mean: [], weather_code: [] } }.to_json)

      # Gemini APIのモック
      mock_client = double('Gemini')
      allow(Gemini).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:generate_content).and_return(gemini_response)
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

    context 'when insufficient data in period' do
      before do
        user.health_records.destroy_all
      end

      it 'raises InsufficientDataError with record count message' do
        expect { service.generate_weekly_report }.to raise_error(
          AiReportService::InsufficientDataError,
          /対象期間の記録が0件しかありません/
        )
      end
    end

    context 'when API returns error' do
      before do
        mock_client = double('Gemini')
        allow(Gemini).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:generate_content).and_raise(StandardError.new('API Error'))
      end

      it 'raises ApiError' do
        expect { service.generate_weekly_report }.to raise_error(
          AiReportService::ApiError
        )
      end
    end

    context 'when Gemini API is temporarily unavailable' do
      let(:primary_client) { instance_double(Gemini::Controllers::Client) }
      let(:fallback_client) { instance_double(Gemini::Controllers::Client) }

      # gemini-ai gem は Faraday::ServerError（5xx）を Gemini::Errors::RequestError で包んで送出する
      def server_error(status)
        faraday_error = Faraday::ServerError.new(
          "the server responded with status #{status} for POST https://generativelanguage.googleapis.com/v1/models/m:generateContent?key=SECRET_KEY",
          { status: status }
        )
        Gemini::Errors::RequestError.new(faraday_error.message, request: faraday_error)
      end

      before do
        allow(Gemini).to receive(:new) do |args|
          args[:options][:model] == described_class::GEMINI_MODEL ? primary_client : fallback_client
        end
        allow(service).to receive(:sleep)
      end

      [500, 503].each do |status|
        it "retries with the primary model on #{status} and succeeds" do
          call_count = 0
          allow(primary_client).to receive(:generate_content) do
            call_count += 1
            raise server_error(status) if call_count == 1

            gemini_response
          end

          expect { service.generate_weekly_report }.to change(WeeklyReport, :count).by(1)
          expect(primary_client).to have_received(:generate_content).twice
          expect(service).to have_received(:sleep).once
        end
      end

      it 'falls back to FALLBACK_MODEL after exhausting retries' do
        allow(primary_client).to receive(:generate_content).and_raise(server_error(503))
        allow(fallback_client).to receive(:generate_content).and_return(gemini_response)

        expect { service.generate_weekly_report }.to change(WeeklyReport, :count).by(1)
        expect(primary_client).to have_received(:generate_content)
          .exactly(described_class::MAX_RETRIES + 1).times
        expect(fallback_client).to have_received(:generate_content).once
      end

      it 'logs the masked cause when falling back' do
        allow(primary_client).to receive(:generate_content).and_raise(server_error(503))
        allow(fallback_client).to receive(:generate_content).and_return(gemini_response)
        allow(Rails.logger).to receive(:warn)

        service.generate_weekly_report

        expect(Rails.logger).to have_received(:warn).with(
          satisfy { |msg| msg.include?(described_class::FALLBACK_MODEL) && msg.include?('status 503') && msg.exclude?('SECRET_KEY') }
        )
      end

      it 'raises ApiError without exposing the API key when fallback also fails' do
        allow(primary_client).to receive(:generate_content).and_raise(server_error(503))
        allow(fallback_client).to receive(:generate_content).and_raise(server_error(503))
        allow(Rails.logger).to receive(:error)

        expect { service.generate_weekly_report }.to raise_error(AiReportService::ApiError) { |e|
          expect(e.message).to include('status 503')
          expect(e.message).not_to include('SECRET_KEY')
          expect(e.cause).to be_nil
        }
        expect(Rails.logger).to have_received(:error).with(satisfy { |msg| msg.exclude?('SECRET_KEY') })
      end

      it 'does not retry or fall back on timeout' do
        # Faraday::TimeoutError は Faraday::ServerError のサブクラスのため gem で RequestError に包まれる
        timeout_error = Faraday::TimeoutError.new('timeout')
        allow(primary_client).to receive(:generate_content)
          .and_raise(Gemini::Errors::RequestError.new(timeout_error.message, request: timeout_error))
        allow(fallback_client).to receive(:generate_content)

        expect { service.generate_weekly_report }.to raise_error(AiReportService::ApiError)
        expect(primary_client).to have_received(:generate_content).once
        expect(fallback_client).not_to have_received(:generate_content)
        expect(service).not_to have_received(:sleep)
      end

      # 504 はサーバー側で処理時間切れになった応答のため、再試行すると待ち時間が積み重なる
      it 'does not retry or fall back on 504' do
        allow(primary_client).to receive(:generate_content).and_raise(server_error(504))
        allow(fallback_client).to receive(:generate_content)

        expect { service.generate_weekly_report }.to raise_error(AiReportService::ApiError)
        expect(primary_client).to have_received(:generate_content).once
        expect(fallback_client).not_to have_received(:generate_content)
        expect(service).not_to have_received(:sleep)
      end

      # 429 は ClientError のため gem で包まれず Faraday::TooManyRequestsError のまま送出される
      def stub_rate_limited
        rate_limit_error = Faraday::TooManyRequestsError.new(
          'the server responded with status 429 for POST https://example.com/m:generateContent?key=SECRET_KEY',
          { status: 429 }
        )
        allow(primary_client).to receive(:generate_content).and_raise(rate_limit_error)
        allow(fallback_client).to receive(:generate_content)
      end

      it 'raises ApiError with the API key masked on 429' do
        stub_rate_limited

        expect { service.generate_weekly_report }.to raise_error(AiReportService::ApiError) { |e|
          expect(e.message).to include('status 429')
          expect(e.message).not_to include('SECRET_KEY')
        }
      end

      it 'does not retry or fall back on 429' do
        stub_rate_limited

        expect { service.generate_weekly_report }.to raise_error(AiReportService::ApiError)
        expect(primary_client).to have_received(:generate_content).once
        expect(fallback_client).not_to have_received(:generate_content)
        expect(service).not_to have_received(:sleep)
      end
    end

    context 'when report for the same period already exists' do
      before do
        create(:weekly_report, user: user,
               week_start: Date.current - AiReportService::DEFAULT_PERIOD_DAYS,
               week_end: Date.current - 1)
      end

      it 'raises ActiveRecord::RecordInvalid' do
        expect { service.generate_weekly_report }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when API returns safety-filtered response' do
      before do
        safety_response = {
          'candidates' => [{ 'finishReason' => 'SAFETY' }],
          'usageMetadata' => { 'totalTokenCount' => 100 }
        }
        mock_client = double('Gemini')
        allow(Gemini).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:generate_content).and_return(safety_response)
      end

      it 'raises ApiError' do
        expect { service.generate_weekly_report }.to raise_error(
          AiReportService::ApiError,
          /正常に完了しませんでした/
        )
      end
    end

    context 'when response has no usageMetadata' do
      before do
        no_metadata_response = {
          'candidates' => [
            {
              'content' => { 'parts' => [{ 'text' => '## 📊 今週の振り返り\n\nテストレポート内容' }] },
              'finishReason' => 'STOP'
            }
          ]
        }
        mock_client = double('Gemini')
        allow(Gemini).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:generate_content).and_return(no_metadata_response)
      end

      it 'sets tokens_used to nil' do
        report = service.generate_weekly_report
        expect(report.tokens_used).to be_nil
      end
    end
  end
end
