require 'rails_helper'

RSpec.describe WeeklyReportExportService, type: :service do
  let(:user) { create(:user) }
  let(:service) { described_class.new(user) }

  describe '#generate_json' do
    context 'レポートが存在する場合' do
      let!(:report) do
        create(:weekly_report, user: user,
                               week_start: Date.new(2026, 1, 5),
                               week_end: Date.new(2026, 1, 11),
                               tokens_used: 2000)
      end

      it '有効なJSONを返す' do
        json_string = service.generate_json
        expect { JSON.parse(json_string) }.not_to raise_error
      end

      it 'version と exported_at を含む' do
        data = JSON.parse(service.generate_json)
        expect(data['version']).to eq(1)
        expect(data['exported_at']).to be_present
      end

      it 'reports 配列にレポートが含まれる' do
        data = JSON.parse(service.generate_json)
        expect(data['reports'].size).to eq(1)
      end

      it '必要なフィールドがすべて含まれる' do
        report_data = JSON.parse(service.generate_json)['reports'].first
        %w[week_start week_end content summary_data predictions tokens_used created_at].each do |field|
          expect(report_data).to have_key(field)
        end
      end

      it 'week_start と week_end が正しい値である' do
        report_data = JSON.parse(service.generate_json)['reports'].first
        expect(report_data['week_start']).to eq('2026-01-05')
        expect(report_data['week_end']).to eq('2026-01-11')
      end

      it 'created_at が含まれる' do
        report_data = JSON.parse(service.generate_json)['reports'].first
        expect(report_data['created_at']).to be_present
      end
    end

    context 'レポートが複数ある場合' do
      let!(:old_report) { create(:weekly_report, user: user, week_start: Date.new(2026, 1, 5), week_end: Date.new(2026, 1, 11)) }
      let!(:new_report) { create(:weekly_report, user: user, week_start: Date.new(2026, 1, 12), week_end: Date.new(2026, 1, 18)) }

      it 'recent順（新しい順）でエクスポートされる' do
        data = JSON.parse(service.generate_json)
        expect(data['reports'].first['week_start']).to eq('2026-01-12')
        expect(data['reports'].last['week_start']).to eq('2026-01-05')
      end
    end

    context 'レポートが存在しない場合' do
      it 'reports が空配列になる' do
        data = JSON.parse(service.generate_json)
        expect(data['reports']).to eq([])
      end
    end

    context '他ユーザーのレポートが存在する場合' do
      let(:other_user) { create(:user) }
      let!(:other_report) { create(:weekly_report, user: other_user) }

      it '自分のレポートのみエクスポートされる' do
        data = JSON.parse(service.generate_json)
        expect(data['reports']).to be_empty
      end
    end
  end
end
