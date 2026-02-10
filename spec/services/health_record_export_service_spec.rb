require 'rails_helper'

RSpec.describe HealthRecordExportService do
  let(:user) { create(:user) }
  let(:service) { described_class.new(user) }

  describe '#generate_csv' do
    context 'レコードがある場合' do
      before do
        create(:health_record, :complete, user: user, recorded_at: Date.new(2026, 1, 1))
        create(:health_record, :complete, user: user, recorded_at: Date.new(2026, 1, 3))
        create(:health_record, :complete, user: user, recorded_at: Date.new(2026, 1, 2))
      end

      it 'BOM付きUTF-8のCSVを返す' do
        csv = service.generate_csv
        expect(csv.bytes[0..2]).to eq([0xEF, 0xBB, 0xBF])
        expect(csv.encoding).to eq(Encoding::UTF_8)
      end

      it 'ヘッダー行が日本語である' do
        csv = service.generate_csv
        lines = csv.delete_prefix("\xEF\xBB\xBF").split("\n")
        header = lines.first
        expect(header).to include('記録日')
        expect(header).to include('体調スコア')
        expect(header).to include('体重(kg)')
        expect(header).to include('睡眠時間(h)')
        expect(header).to include('運動時間(分)')
        expect(header).to include('歩数')
        expect(header).to include('心拍数(bpm)')
        expect(header).to include('最高血圧(mmHg)')
        expect(header).to include('最低血圧(mmHg)')
        expect(header).to include('体温(℃)')
        expect(header).to include('メモ')
        expect(header).to include('天気')
        expect(header).to include('気温(℃)')
        expect(header).to include('湿度(%)')
        expect(header).to include('気圧(hPa)')
      end

      it 'データが日付降順で並ぶ' do
        csv = service.generate_csv
        lines = csv.delete_prefix("\xEF\xBB\xBF").split("\n")
        data_lines = lines[1..]
        dates = data_lines.map { |line| line.split(',').first }
        expect(dates).to eq(['2026-01-03', '2026-01-02', '2026-01-01'])
      end

      it 'レコード数分のデータ行がある' do
        csv = service.generate_csv
        lines = csv.delete_prefix("\xEF\xBB\xBF").split("\n")
        expect(lines.size).to eq(4) # ヘッダー + 3データ行
      end
    end

    context 'レコードがない場合' do
      it 'ヘッダーのみのCSVを返す' do
        csv = service.generate_csv
        lines = csv.delete_prefix("\xEF\xBB\xBF").split("\n")
        expect(lines.size).to eq(1)
        expect(lines.first).to include('記録日')
      end
    end

    context '他ユーザーのレコードがある場合' do
      let(:other_user) { create(:user) }

      before do
        create(:health_record, user: user, recorded_at: Date.new(2026, 1, 1))
        create(:health_record, user: other_user, recorded_at: Date.new(2026, 1, 2))
      end

      it '自分のレコードのみエクスポートされる' do
        csv = service.generate_csv
        lines = csv.delete_prefix("\xEF\xBB\xBF").split("\n")
        expect(lines.size).to eq(2) # ヘッダー + 1データ行
      end
    end
  end
end
