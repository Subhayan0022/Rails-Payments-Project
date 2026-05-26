# Rack::Attack — rate limiting and replay attack protection.
# Uses a Redis-backed store so throttle counters are shared across processes and
# survive restarts. Falls back to an in-process memory store in test, or if Redis
# is unreachable at boot.
class Rack::Attack
  Rack::Attack.cache.store =
    if Rails.env.test?
      ActiveSupport::Cache::MemoryStore.new
    else
      begin
        ActiveSupport::Cache::RedisCacheStore.new(
          url: ENV.fetch("RACK_ATTACK_REDIS_URL") { ENV.fetch("REDIS_URL", "redis://localhost:6379/0") },
          namespace: "rack_attack",
          error_handler: lambda { |method:, returning:, exception:|
            Rails.logger.warn("[rack-attack] redis error in #{method}: #{exception.class}: #{exception.message}")
          }
        )
      rescue StandardError => e
        Rails.logger.warn("[rack-attack] Redis unavailable, falling back to memory store: #{e.message}")
        ActiveSupport::Cache::MemoryStore.new
      end
    end

  # Throttle all requests by IP (100 requests / 60s)
  throttle("req/ip", limit: 100, period: 60) do |req|
    req.ip unless req.path.start_with?("/up")
  end

  # Tighter throttle for payment creation (20 requests / 60s per IP)
  throttle("payments/ip", limit: 20, period: 60) do |req|
    req.ip if req.path.include?("/payments") && req.post?
  end

  # Block suspicious User-Agents
  blocklist("block bad actors") do |req|
    req.user_agent.nil? || req.user_agent.empty?
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |env|
    [
      429,
      { "Content-Type" => "application/json" },
      [{ error: "Too Many Requests", retry_after: 60 }.to_json]
    ]
  end
end
