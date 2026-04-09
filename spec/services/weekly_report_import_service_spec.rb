require 'rails_helper'

RSpec.describe WeeklyReportImportService, type: :service do
  let(:user) { create(:user) }

  def build_json(reports)
    JSON.generate({ version: 1, exported_at: Time.current.iso8601, reports: reports })
  end

  def valid_report_data(overrides = {})
    {
      'week_start' => '2026-01-05',
      'week_end' => '2026-01-11',
      'content' => '## 今週の振り返り\n\n体調は安定していました。',
      'summary_data' => { 'record_count' => 5, 'avg_mood' => 3.5 },
      'predictions' => { 'warning_dates' => [] },
      'tokens_used' => 1500,
      'created_at' => '2026-01-12T10:00:00Z'
    }.merge(overrides)
  end

  describe '#import' do
    context '正常系' do
      it 'レポートを新規インポートできる' do
        json = build_json([valid_report_data])
        service = described_class.new(user, json)

        expect { service.import }.to change(WeeklyReport, :count).by(1)
      end

      it 'インポート件数が result に含まれる' do
        json = build_json([valid_report_data])
        result = described_class.new(user, json).import

        expect(result[:imported]).to eq(1)
        expect(result[:skipped]).to eq(0)
        expect(result[:errors]).to be_empty
      end

      it 'created_at が元の値で復元される' do
        json = build_json([valid_report_data])
        described_class.new(user, json).import

        report = WeeklyReport.find_by(user: user, week_start: Date.new(2026, 1, 5))
        expect(report.created_at).to be_within(1.second).of(Time.zone.parse('2026-01-12T10:00:00Z'))
      end

      it 'tokens_used が正しく保存される' do
        json = build_json([valid_report_data])
        described_class.new(user, json).import

        report = WeeklyReport.find_by(user: user, week_start: Date.new(2026, 1, 5))
        expect(report.tokens_used).to eq(1500)
      end

      it '複数レポートをインポートできる' do
        data1 = valid_report_data('week_start' => '2026-01-05', 'week_end' => '2026-01-11')
        data2 = valid_report_data('week_start' => '2026-01-12', 'week_end' => '2026-01-18')
        json = build_json([data1, data2])

        expect { described_class.new(user, json).import }.to change(WeeklyReport, :count).by(2)
      end
    end

    context '重複戦略: skip（デフォルト）' do
      let!(:existing) do
        create(:weekly_report, user: user, week_start: Date.new(2026, 1, 5), week_end: Date.new(2026, 1, 11),
                               content: '既存のコンテンツ')
      end

      it '既存レポートをスキップする' do
        json = build_json([valid_report_data])
        result = described_class.new(user, json).import

        expect(result[:skipped]).to eq(1)
        expect(result[:imported]).to eq(0)
      end

      it '既存レポートの内容が変わらない' do
        json = build_json([valid_report_data])
        described_class.new(user, json).import

        expect(existing.reload.content).to eq('既存のコンテンツ')
      end
    end

    context '重複戦略: overwrite' do
      let!(:existing) do
        create(:weekly_report, user: user, week_start: Date.new(2026, 1, 5), week_end: Date.new(2026, 1, 11),
                               content: '既存のコンテンツ')
      end

      it '既存レポートを上書きする' do
        json = build_json([valid_report_data])
        result = described_class.new(user, json, duplicate_strategy: 'overwrite').import

        expect(result[:imported]).to eq(1)
        expect(result[:skipped]).to eq(0)
      end

      it '既存レポートの内容が更新される' do
        json = build_json([valid_report_data])
        described_class.new(user, json, duplicate_strategy: 'overwrite').import

        expect(existing.reload.content).to eq(valid_report_data['content'])
      end
    end

    context '異常系' do
      it '不正なJSONはエラーを返す' do
        result = described_class.new(user, 'invalid json').import

        expect(result[:errors]).not_to be_empty
        expect(result[:imported]).to eq(0)
      end

      it 'reports キーがない場合はエラーを返す' do
        json = JSON.generate({ version: 1 })
        result = described_class.new(user, json).import

        expect(result[:errors]).not_to be_empty
      end

      it 'week_start が欠けている場合はエラーを返す' do
        data = valid_report_data.except('week_start')
        json = build_json([data])
        result = described_class.new(user, json).import

        expect(result[:errors].first).to include('week_start')
        expect(result[:imported]).to eq(0)
      end

      it 'content が欠けている場合はエラーを返す' do
        data = valid_report_data.except('content')
        json = build_json([data])
        result = described_class.new(user, json).import

        expect(result[:errors].first).to include('content')
      end
    end

    context '他ユーザーへの影響' do
      let(:other_user) { create(:user) }
      let!(:other_report) do
        create(:weekly_report, user: other_user, week_start: Date.new(2026, 1, 5), week_end: Date.new(2026, 1, 11))
      end

      it '他ユーザーのレポートに影響しない' do
        json = build_json([valid_report_data])
        described_class.new(user, json, duplicate_strategy: 'overwrite').import

        expect(other_report.reload.user).to eq(other_user)
        expect(WeeklyReport.where(user: user).count).to eq(1)
        expect(WeeklyReport.where(user: other_user).count).to eq(1)
      end
    end
  end
end
