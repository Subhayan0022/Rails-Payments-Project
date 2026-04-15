Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("ALLOWED_ORIGINS", "*")

    resource "*",
      headers: :any,
      expose: ["X-Request-Id"],
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
