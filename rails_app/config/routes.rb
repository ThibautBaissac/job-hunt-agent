Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  resource :profile, only: %i[show edit update]
  resource :gmail_connection, only: [ :destroy ]
  resources :cvs, only: %i[index show new create] do
    member do
      post :analyze
      post :activate
    end

    resources :optimizations, only: %i[new create], module: :cvs
  end

  resources :job_offers, only: %i[index new create show] do
    collection do
      get :new_manual
      post :create_manual
    end
  end

  root to: "home#index"

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
