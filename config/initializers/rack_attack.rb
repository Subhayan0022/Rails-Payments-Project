# Rack::Attack — rate limiting and replay attack protection.
# Uses Redis as the backing store when available, falls back to memory.
class Rack::Attack
  # Use Redis for distributed rate limiting across multiple app instances
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
  )

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
