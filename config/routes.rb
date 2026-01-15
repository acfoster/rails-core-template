Rails.application.routes.draw do
  # Devise routes
  devise_for :users, path: "users", controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions",
    confirmations: "users/confirmations"
  }

  # Public root
  root "pages#home"

  # Authenticated user routes
  authenticate :user do
    get "dashboard", to: "dashboard#index", as: :dashboard
    get "dashboard_poll", to: "dashboard#poll", as: :dashboard_poll

    # Subscription management
    resource :subscription, only: [ :new, :create ] do
      get :portal, on: :collection
    end

    # Profile pages
    scope :profile, as: :profile do
      get "/", to: "users#profile", as: ""
      get "account", to: "users#account"
      get "payment", to: "users#payment"
      get "billing", to: "users#billing"
    end
  end

  # Stripe integration routes
  post '/stripe/create_checkout_session', to: 'stripe#create_checkout_session'
  post '/stripe/webhook', to: 'stripe#webhook'

  # Admin routes
  namespace :admin do
    root to: "dashboard#index"
    resources :users, only: [ :index, :show ] do
      member do
        post :extend_trial
        post :toggle_free_access
        post :toggle_suspension
        post :set_discount
      end
    end
    resources :logs, only: [ :index, :show ] do
      collection do
        get :stats
        get :export
      end
    end
    resources :financials, only: [ :index ]
  end


  # Public pages
  get "terms", to: "pages#terms", as: :terms
  get "privacy", to: "pages#privacy", as: :privacy
  get "contact", to: "pages#contact", as: :contact

  # Webhooks (no authentication)
  post "webhooks/stripe", to: "webhooks#stripe"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
