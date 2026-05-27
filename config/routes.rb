Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :payments, only: [:create, :show]
      get "/metrics", to: "metrics#index"
    end
  end

  require "sidekiq/web"

  sidekiq_user = ENV["SIDEKIQ_USER"]
  sidekiq_password = ENV["SIDEKIQ_PASSWORD"]

  if sidekiq_user.present? && sidekiq_password.present?
    Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
      # Constant-time comparison over fixed-length digests to avoid leaking
      # credential length or content via timing.
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(username),
        ::Digest::SHA256.hexdigest(sidekiq_user)
      ) & ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(password),
        ::Digest::SHA256.hexdigest(sidekiq_password)
      )
    end
    mount Sidekiq::Web => "/sidekiq"
  elsif !Rails.env.production?
    # No credentials configured, only safe to expose outside production.
    mount Sidekiq::Web => "/sidekiq"
  end
end
