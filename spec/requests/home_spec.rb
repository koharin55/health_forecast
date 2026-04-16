require 'rails_helper'

RSpec.describe 'Home', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET /' do
    context 'with records spanning multiple periods' do
      let!(:record_3d)   { create(:health_record, user: user, recorded_at: 3.days.ago.to_date, weight: 60) }
      let!(:record_20d)  { create(:health_record, user: user, recorded_at: 20.days.ago.to_date, weight: 61) }
      let!(:record_100d) { create(:health_record, user: user, recorded_at: 100.days.ago.to_date, weight: 62) }
      let!(:record_300d) { create(:health_record, user: user, recorded_at: 300.days.ago.to_date, weight: 63) }

      it 'returns success with default period (7d)' do
        get root_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include('最新記録から1週間')
        expect(response.body).to include('turbo-frame id="charts"')
      end

      it 'includes all 5 period switcher links' do
        get root_path
        %w[7d 30d 90d 180d 365d].each do |p|
          expect(response.body).to include("period=#{p}")
        end
      end

      # 集約後のバケット日付でチャートデータを検証するヘルパー
      def weight_bucket_for(record, interval)
        date = case interval
               when :daily   then record.recorded_at.to_date
               when :weekly  then record.recorded_at.to_date.beginning_of_week
               when :monthly then record.recorded_at.to_date.beginning_of_month
               end
        %("x":"#{date}","y":#{record.weight.to_f})
      end

      it 'shows 30d label and weekly-bucketed data when period=30d' do
        get root_path(period: '30d')
        expect(response).to have_http_status(:success)
        expect(response.body).to include('最新記録から1ヶ月')
        expect(response.body).to include(weight_bucket_for(record_20d, :weekly))
        expect(response.body).not_to include(weight_bucket_for(record_100d, :weekly))
      end

      it 'shows 90d label and weekly-bucketed data when period=90d' do
        get root_path(period: '90d')
        expect(response.body).to include('最新記録から3ヶ月')
        expect(response.body).to include(weight_bucket_for(record_20d, :weekly))
        expect(response.body).not_to include(weight_bucket_for(record_100d, :weekly))
      end

      it 'shows 180d label and monthly-bucketed data when period=180d' do
        get root_path(period: '180d')
        expect(response.body).to include('最新記録から半年')
        expect(response.body).to include(weight_bucket_for(record_100d, :monthly))
        expect(response.body).not_to include(weight_bucket_for(record_300d, :monthly))
      end

      it 'shows 365d label and monthly-bucketed data when period=365d' do
        get root_path(period: '365d')
        expect(response.body).to include('最新記録から1年')
        expect(response.body).to include(weight_bucket_for(record_300d, :monthly))
      end

      it 'falls back to default when period is invalid' do
        get root_path(period: 'invalid')
        expect(response).to have_http_status(:success)
        expect(response.body).to include('最新記録から1週間')
      end
    end

    context 'when 7d and latest record is older than 7 days' do
      let!(:old_latest) { create(:health_record, user: user, recorded_at: 20.days.ago.to_date, weight: 65) }
      let!(:old_prev)   { create(:health_record, user: user, recorded_at: 30.days.ago.to_date, weight: 64) }

      it 'shows chart data anchored at the latest record date' do
        get root_path(period: '7d')
        # 最新レコード(20日前)を起点に過去7日のデータが表示される
        expect(response.body).to include(%("x":"#{old_latest.recorded_at}","y":#{old_latest.weight.to_f}))
        # 30日前は7日前より外なので含まれない
        expect(response.body).not_to include(%("x":"#{old_prev.recorded_at}","y":#{old_prev.weight.to_f}))
      end
    end
  end
end
