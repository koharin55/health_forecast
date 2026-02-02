require 'rails_helper'

RSpec.describe 'Api::V1::PushSubscriptions', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'POST /api/v1/push_subscriptions' do
    let(:valid_params) do
      {
        push_subscription: {
          endpoint: 'https://push.example.com/subscription/123',
          p256dh_key: 'BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkA',
          auth_key: 'tBHItJI5svbpez7KI4CCXg'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new subscription' do
        expect {
          post '/api/v1/push_subscriptions', params: valid_params, as: :json
        }.to change(PushSubscription, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)).to include('id', 'active')
      end
    end

    context 'when subscription already exists' do
      before do
        create(:push_subscription,
               user: user,
               endpoint: valid_params[:push_subscription][:endpoint])
      end

      it 'updates the existing subscription' do
        expect {
          post '/api/v1/push_subscriptions', params: valid_params, as: :json
        }.not_to change(PushSubscription, :count)

        expect(response).to have_http_status(:created)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          push_subscription: {
            endpoint: '',
            p256dh_key: '',
            auth_key: ''
          }
        }
      end

      it 'returns unprocessable entity' do
        post '/api/v1/push_subscriptions', params: invalid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to have_key('errors')
      end
    end

    context 'without authentication' do
      before { sign_out user }

      it 'returns unauthorized' do
        post '/api/v1/push_subscriptions', params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/push_subscriptions' do
    let!(:subscription) do
      create(:push_subscription,
             user: user,
             endpoint: 'https://push.example.com/to-delete')
    end

    context 'with existing subscription' do
      it 'deletes the subscription' do
        expect {
          delete "/api/v1/push_subscriptions?endpoint=#{CGI.escape(subscription.endpoint)}"
        }.to change(PushSubscription, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with non-existing endpoint' do
      it 'returns not found' do
        delete '/api/v1/push_subscriptions?endpoint=https://unknown.com'

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/v1/push_subscriptions/vapid_public_key' do
    it 'returns the VAPID public key' do
      get '/api/v1/push_subscriptions/vapid_public_key', as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to have_key('vapid_public_key')
    end
  end
end
