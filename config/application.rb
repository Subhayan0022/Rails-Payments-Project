require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module PaymentGateway
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.api_only = true

    # Use Sidekiq for background jobs
    config.active_job.queue_adapter = :sidekiq

    # Structured JSON logging via lograge
    config.lograge.enabled = true
    config.lograge.formatter = Lograge::Formatters::Json.new
    config.lograge.custom_options = lambda do |event|
      {
        request_id: event.payload[:request_id],
        user_agent: event.payload[:user_agent],
        remote_ip: event.payload[:remote_ip]
      }.compact
    end

    # Autoload service objects, validators etc.
    config.autoload_paths += %w[
      app/services
      app/workers
      app/serializers
      app/validators
      app/lib
      lib
    ].map { |p| Rails.root.join(p) }

    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc
  end
end
