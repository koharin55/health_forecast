require 'rails_helper'

RSpec.describe 'Api::V1::HealthRecords', type: :request do
  let(:user) { create(:user, :with_api_token, :with_location) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{user.raw_api_token}",
      'Content-Type' => 'application/json'
    }
  end

  describe 'POST /api/v1/health_records' do
    context 'with valid token and new record' do
      let(:params) do
        {
          recorded_at: Date.current.to_s,
          weight: 65.5,
          steps: 8000,
          mood: 4,
          sleep_hours: 7.5
        }
      end

      before do
        allow_any_instance_of(HealthRecord).to receive(:fetch_and_set_weather!).and_return(true)
      end

      it 'creates a new health record' do
        expect {
          post '/api/v1/health_records', params: params.to_json, headers: headers
        }.to change(HealthRecord, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['weight']).to eq('65.5')
        expect(json['steps']).to eq(8000)
        expect(json['mood']).to eq(4)
        expect(json['merged']).to be false
      end

      it 'fetches weather data for new records' do
        expect_any_instance_of(HealthRecord).to receive(:fetch_and_set_weather!)

        post '/api/v1/health_records', params: params.to_json, headers: headers
      end

      it 'defaults to today when recorded_at is omitted' do
        post '/api/v1/health_records',
          params: { steps: 5000 }.to_json,
          headers: headers

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['recorded_at']).to eq(Date.current.to_s)
      end
    end

    context 'with existing record (merge)' do
      let!(:existing_record) do
        create(:health_record, user: user, recorded_at: Date.current, weight: 60.0, mood: 4, steps: nil)
      end

      it 'merges nil attributes without overwriting existing values' do
        post '/api/v1/health_records',
          params: { recorded_at: Date.current.to_s, weight: 70.0, steps: 8000 }.to_json,
          headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['merged']).to be true
        expect(json['weight']).to eq('60.0')   # 既存値を保持
        expect(json['steps']).to eq(8000)       # nilだったので補完
      end

      it 'does not fetch weather for merged records' do
        expect_any_instance_of(HealthRecord).not_to receive(:fetch_and_set_weather!)

        post '/api/v1/health_records',
          params: { recorded_at: Date.current.to_s, steps: 8000 }.to_json,
          headers: headers
      end
    end

    context 'with invalid token' do
      it 'returns unauthorized' do
        post '/api/v1/health_records',
          params: { steps: 8000 }.to_json,
          headers: { 'Authorization' => 'Bearer invalid_token', 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('認証に失敗しました')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post '/api/v1/health_records',
          params: { steps: 8000 }.to_json,
          headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid recorded_at' do
      it 'returns unprocessable entity' do
        post '/api/v1/health_records',
          params: { recorded_at: 'invalid-date', steps: 8000 }.to_json,
          headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('日付形式が不正')
      end
    end

    context 'with validation error' do
      it 'returns unprocessable entity for invalid mood' do
        post '/api/v1/health_records',
          params: { mood: 10 }.to_json,
          headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with session authentication' do
      let(:session_user) { create(:user) }

      before { sign_in session_user }

      it 'works with session authentication' do
        allow_any_instance_of(HealthRecord).to receive(:fetch_and_set_weather!).and_return(false)

        post '/api/v1/health_records',
          params: { steps: 5000 }.to_json,
          headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:created)
      end
    end
  end
end
