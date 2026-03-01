Rails.application.routes.draw do
  devise_for :users

  authenticated :user do
    root to: 'home#index', as: :authenticated_root
    resources :health_records do
      collection do
        get :export
        get :import, action: :import_form
        post :import
      end
    end
    resources :weekly_reports, only: [:index, :show, :new, :create, :destroy]
    resource :mypage, only: [:show], controller: 'mypage' do
      patch :update_profile, on: :member
      patch :update_password, on: :member
      patch :update_location, on: :member
      post :search_zipcode, on: :collection
      post :backfill_weather, on: :collection
      post :generate_api_token, on: :member
      delete :revoke_api_token, on: :member
      delete :destroy_account, on: :member
    end

    get '/guides/ios_shortcut', to: 'guides#ios_shortcut', as: :guides_ios_shortcut

    # 旧設定ページからリダイレクト
    get '/settings', to: redirect('/mypage')
  end

  # API endpoints
  namespace :api do
    namespace :v1 do
      resources :health_records, only: [:create]
      resources :push_subscriptions, only: [:create] do
        collection do
          delete :destroy, action: :destroy
          get :vapid_public_key
        end
      end
    end
  end

  root to: redirect('/users/sign_in')

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
