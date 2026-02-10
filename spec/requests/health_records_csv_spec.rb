require 'rails_helper'

RSpec.describe 'Health Records CSV', type: :request do
  let(:user) { create(:user) }

  describe 'GET /health_records/export' do
    context '認証済みの場合' do
      before { sign_in user }

      it 'CSVファイルをダウンロードできる' do
        create(:health_record, user: user, recorded_at: Date.new(2026, 1, 15))

        get export_health_records_path

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/csv')
        expect(response.headers['Content-Disposition']).to include('.csv')
        expect(response.body.bytes[0..2]).to eq([0xEF, 0xBB, 0xBF])
      end

      it 'レコードがなくてもヘッダーのみのCSVを返す' do
        get export_health_records_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('記録日')
      end
    end

    context '未認証の場合' do
      it 'アクセスできない' do
        get '/health_records/export'

        expect(response).to have_http_status(:not_found).or redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /health_records/import' do
    context '認証済みの場合' do
      before { sign_in user }

      it 'インポートフォームが表示される' do
        get import_health_records_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('CSVインポート')
      end
    end

    context '未認証の場合' do
      it 'アクセスできない' do
        get '/health_records/import'

        expect(response).to have_http_status(:not_found).or redirect_to(new_user_session_path)
      end
    end
  end

  describe 'POST /health_records/import' do
    context '認証済みの場合' do
      before { sign_in user }

      it 'CSVファイルを正常にインポートできる' do
        csv_content = "記録日,体調スコア,体重(kg),睡眠時間(h),運動時間(分),歩数,心拍数(bpm),最高血圧(mmHg),最低血圧(mmHg),体温(℃),メモ\n2026-01-15,4,65.5,7.5,30,8000,70,120,80,36.5,テスト\n"

        file = Rack::Test::UploadedFile.new(
          StringIO.new(csv_content), 'text/csv', original_filename: 'test.csv'
        )

        post import_health_records_path, params: { file: file, duplicate_strategy: 'skip' }

        expect(response).to redirect_to(health_records_path)
        follow_redirect!
        expect(response.body).to include('1件インポートしました')
        expect(user.health_records.count).to eq(1)
      end

      it 'ファイル未選択の場合エラーメッセージが表示される' do
        post import_health_records_path

        expect(response).to redirect_to(import_health_records_path)
        follow_redirect!
        expect(response.body).to include('ファイルを選択してください')
      end
    end

    context '未認証の場合' do
      it 'アクセスできない' do
        post '/health_records/import'

        expect(response).to have_http_status(:not_found).or redirect_to(new_user_session_path)
      end
    end
  end
end
