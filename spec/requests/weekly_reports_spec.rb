require 'rails_helper'

RSpec.describe 'WeeklyReports', type: :request do
  let(:user) { create(:user, :with_location) }

  describe 'GET /weekly_reports/new' do
    context '認証済みの場合' do
      before { sign_in user }

      it 'フォーム画面を表示できる' do
        get new_weekly_report_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('AI週次レポート生成')
        expect(response.body).to include('開始日')
        expect(response.body).to include('終了日')
      end
    end

    context '未認証の場合' do
      it 'アクセスできない' do
        get '/weekly_reports/new'

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /weekly_reports' do
    before { sign_in user }

    context 'バリデーション' do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(:gemini_api_key).and_return('test_api_key')
      end

      it '終了日が開始日より前の場合エラーになる' do
        post weekly_reports_path, params: {
          week_start: '2026-02-10',
          week_end: '2026-02-05'
        }

        expect(response).to redirect_to(new_weekly_report_path(week_start: '2026-02-10', week_end: '2026-02-05'))
        follow_redirect!
        expect(response.body).to include('終了日は開始日より後の日付を指定してください')
      end

      it '未来の日付が指定された場合エラーになる' do
        future_date = (Date.current + 5).to_s
        post weekly_reports_path, params: {
          week_start: Date.current.to_s,
          week_end: future_date
        }

        expect(response).to redirect_to(new_weekly_report_path(week_start: Date.current.to_s, week_end: future_date))
        follow_redirect!
        expect(response.body).to include('未来の日付は指定できません')
      end

      it "#{AiReportService::MAX_PERIOD_DAYS}日を超える期間はエラーになる" do
        week_start = (Date.current - 40).to_s
        week_end = (Date.current - 1).to_s
        post weekly_reports_path, params: {
          week_start: week_start,
          week_end: week_end
        }

        expect(response).to redirect_to(new_weekly_report_path(week_start: week_start, week_end: week_end))
        follow_redirect!
        expect(response.body).to include("対象期間は最大#{AiReportService::MAX_PERIOD_DAYS}日間までです")
      end

      it "ちょうど#{AiReportService::MAX_PERIOD_DAYS}日間は期間バリデーションを通過する" do
        week_start = Date.current - AiReportService::MAX_PERIOD_DAYS
        week_end = Date.current - 1
        post weekly_reports_path, params: {
          week_start: week_start.to_s,
          week_end: week_end.to_s
        }

        # 期間上限エラーではない（データ不足リダイレクトは許容）
        if response.redirect?
          follow_redirect!
          expect(response.body).not_to include("対象期間は最大#{AiReportService::MAX_PERIOD_DAYS}日間までです")
        end
      end

      it '不正な日付形式の場合はデフォルト値にフォールバックする' do
        post weekly_reports_path, params: {
          week_start: 'invalid',
          week_end: 'invalid'
        }

        # デフォルト値が適用されるため、期間バリデーションエラーにはならない
        expect(response).not_to have_http_status(:internal_server_error)
      end

      it 'パラメータ未送信の場合はデフォルト値で動作する' do
        post weekly_reports_path

        expect(response).not_to have_http_status(:internal_server_error)
      end

      it '開始日が未来の場合エラーになる' do
        future_start = (Date.current + 3).to_s
        future_end = (Date.current + 5).to_s
        post weekly_reports_path, params: {
          week_start: future_start,
          week_end: future_end
        }

        expect(response).to redirect_to(new_weekly_report_path(week_start: future_start, week_end: future_end))
        follow_redirect!
        expect(response.body).to include('未来の日付は指定できません')
      end
    end
  end

  describe 'DELETE /weekly_reports/:id' do
    context '認証済みの場合' do
      before { sign_in user }

      it 'レポートを削除できる' do
        report = create(:weekly_report, user: user)

        expect {
          delete weekly_report_path(report)
        }.to change(WeeklyReport, :count).by(-1)
      end

      it '削除後に一覧画面にリダイレクトされる' do
        report = create(:weekly_report, user: user)

        delete weekly_report_path(report)

        expect(response).to redirect_to(weekly_reports_path)
        follow_redirect!
        expect(response.body).to include('レポートを削除しました')
      end

      it '他のユーザーのレポートは削除できない' do
        other_user = create(:user)
        other_report = create(:weekly_report, user: other_user)

        expect {
          delete weekly_report_path(other_report)
        }.not_to change(WeeklyReport, :count)
      end
    end

    context '未認証の場合' do
      it 'アクセスできない' do
        report = create(:weekly_report, user: user)

        delete "/weekly_reports/#{report.id}"

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
