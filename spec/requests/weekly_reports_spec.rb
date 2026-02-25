require 'rails_helper'

RSpec.describe 'WeeklyReports', type: :request do
  let(:user) { create(:user) }

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
