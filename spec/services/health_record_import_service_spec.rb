require 'rails_helper'

RSpec.describe HealthRecordImportService do
  let(:user) { create(:user) }
  let(:bom) { "\xEF\xBB\xBF" }
  let(:header) { "記録日,体調スコア,体重(kg),睡眠時間(h),運動時間(分),歩数,心拍数(bpm),最高血圧(mmHg),最低血圧(mmHg),体温(℃),メモ,天気,気温(℃),湿度(%),気圧(hPa)" }

  describe '#import' do
    context '正常系: 新規レコードのインポート' do
      let(:csv_content) do
        <<~CSV
          #{header}
          2026-01-15,4,65.5,7.5,30,8000,70,120,80,36.5,良い日だった,,,
        CSV
      end

      it '新規レコードを作成する' do
        service = described_class.new(user, csv_content)
        result = service.import

        expect(result[:imported]).to eq(1)
        expect(result[:skipped]).to eq(0)
        expect(result[:errors]).to be_empty

        record = user.health_records.find_by(recorded_at: Date.new(2026, 1, 15))
        expect(record).to be_present
        expect(record.mood).to eq(4)
        expect(record.weight).to eq(65.5)
        expect(record.sleep_hours).to eq(7.5)
        expect(record.exercise_minutes).to eq(30)
        expect(record.steps).to eq(8000)
        expect(record.heart_rate).to eq(70)
        expect(record.systolic_pressure).to eq(120)
        expect(record.diastolic_pressure).to eq(80)
        expect(record.body_temperature).to eq(36.5)
        expect(record.notes).to eq('良い日だった')
      end

      it '複数レコードをインポートする' do
        csv = <<~CSV
          #{header}
          2026-01-15,4,65.5,7.5,,,,,,,,,,
          2026-01-16,3,66.0,8.0,,,,,,,,,,
        CSV

        service = described_class.new(user, csv)
        result = service.import

        expect(result[:imported]).to eq(2)
        expect(user.health_records.count).to eq(2)
      end
    end

    context 'BOM付きCSV' do
      it 'BOM付きCSVを正しく処理する' do
        csv = bom + <<~CSV
          #{header}
          2026-01-15,4,65.5,7.5,,,,,,,,,,
        CSV

        service = described_class.new(user, csv)
        result = service.import

        expect(result[:imported]).to eq(1)
        expect(result[:errors]).to be_empty
      end
    end

    context '重複戦略: skip（デフォルト）' do
      before do
        create(:health_record, user: user, recorded_at: Date.new(2026, 1, 15), mood: 3, weight: 60.0)
      end

      it '同一日付の既存データを保持する' do
        csv = <<~CSV
          #{header}
          2026-01-15,5,70.0,8.0,,,,,,,,,,
        CSV

        service = described_class.new(user, csv, duplicate_strategy: 'skip')
        result = service.import

        expect(result[:imported]).to eq(0)
        expect(result[:skipped]).to eq(1)

        record = user.health_records.find_by(recorded_at: Date.new(2026, 1, 15))
        expect(record.mood).to eq(3)
        expect(record.weight).to eq(60.0)
      end
    end

    context '重複戦略: overwrite' do
      before do
        create(:health_record, user: user, recorded_at: Date.new(2026, 1, 15), mood: 3, weight: 60.0)
      end

      it '同一日付の既存データを上書きする' do
        csv = <<~CSV
          #{header}
          2026-01-15,5,70.0,8.0,,,,,,,,,,
        CSV

        service = described_class.new(user, csv, duplicate_strategy: 'overwrite')
        result = service.import

        expect(result[:imported]).to eq(1)
        expect(result[:skipped]).to eq(0)

        record = user.health_records.find_by(recorded_at: Date.new(2026, 1, 15))
        expect(record.mood).to eq(5)
        expect(record.weight).to eq(70.0)
      end
    end

    context 'バリデーションエラー' do
      it '行番号付きでエラーを報告する' do
        csv = <<~CSV
          #{header}
          2026-01-15,4,65.5,7.5,,,,,,,,,,
          2026-01-16,9,65.5,7.5,,,,,,,,,,
        CSV

        service = described_class.new(user, csv)
        result = service.import

        expect(result[:imported]).to eq(1)
        expect(result[:errors].size).to eq(1)
        expect(result[:errors].first).to include('3行目')
      end

      it '記録日が空の場合エラーを報告する' do
        csv = <<~CSV
          #{header}
          ,4,65.5,7.5,,,,,,,,,,
        CSV

        service = described_class.new(user, csv)
        result = service.import

        expect(result[:imported]).to eq(0)
        expect(result[:errors].size).to eq(1)
        expect(result[:errors].first).to include('2行目')
      end
    end

    context '空ファイル・ヘッダーのみ' do
      it 'ヘッダーのみの場合は空結果を返す' do
        csv = "#{header}\n"

        service = described_class.new(user, csv)
        result = service.import

        expect(result[:imported]).to eq(0)
        expect(result[:skipped]).to eq(0)
        expect(result[:errors]).to be_empty
      end

      it '空文字列の場合はエラーを返す' do
        service = described_class.new(user, '')
        result = service.import

        expect(result[:imported]).to eq(0)
        expect(result[:errors]).to include('CSVデータが空です')
      end
    end

    context '不正な日付形式' do
      it '解析不能な日付はエラーとして報告する' do
        csv = <<~CSV
          #{header}
          invalid-date,4,65.5,7.5,,,,,,,,,,
        CSV

        service = described_class.new(user, csv)
        result = service.import

        expect(result[:imported]).to eq(0)
        expect(result[:errors].size).to eq(1)
        expect(result[:errors].first).to include('2行目')
      end
    end

    context '必須列がない場合' do
      it '記録日列がない場合はエラーを返す' do
        csv = <<~CSV
          体調スコア,体重(kg)
          4,65.5
        CSV

        service = described_class.new(user, csv)
        result = service.import

        expect(result[:imported]).to eq(0)
        expect(result[:errors]).to include('必須列「記録日」がCSVに含まれていません')
      end
    end

    context '天候データ列が含まれる場合' do
      it '天候データ列は無視する' do
        csv = <<~CSV
          #{header}
          2026-01-15,4,65.5,7.5,30,8000,70,120,80,36.5,良い日だった,晴れ,18.5,55,1013.2
        CSV

        service = described_class.new(user, csv)
        result = service.import

        expect(result[:imported]).to eq(1)
        record = user.health_records.find_by(recorded_at: Date.new(2026, 1, 15))
        expect(record.weather_description).to be_nil
        expect(record.weather_temperature).to be_nil
      end
    end
  end
end
