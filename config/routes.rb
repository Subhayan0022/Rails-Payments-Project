Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :payments, only: [:create, :show]
      get "/metrics", to: "metrics#index"
    end
  end

  # Sidekiq Web UI (disable in production or add auth)
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"
end
