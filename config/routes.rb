Rails.application.routes.draw do
  devise_for :users

  authenticated :user do
    root to: 'home#index', as: :authenticated_root
    resources :health_records
  end

  # API endpoints
  namespace :api do
    namespace :v1 do
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
