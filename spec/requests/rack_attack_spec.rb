require 'rails_helper'

RSpec.describe "Rack::Attack", type: :request do
  before { Rack::Attack.cache.store.clear }

  describe "missing User-Agent blocklist" do
    it "blocks requests without a User-Agent header" do
      get "/up", headers: { "User-Agent" => "" }
      expect(response.status).to eq(403)
    end

    it "allows requests with a User-Agent header" do
      get "/up", headers: { "User-Agent" => "rspec-test" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "global IP throttle (100 req / 60s)" do
    it "returns 429 with a JSON body after exceeding the limit" do
      100.times { get "/api/v1/metrics", headers: { "User-Agent" => "rspec-test" } }

      get "/api/v1/metrics", headers: { "User-Agent" => "rspec-test" }

      expect(response.status).to eq(429)
      expect(response.content_type).to start_with("application/json")
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("Too Many Requests")
      expect(body["retry_after"]).to eq(60)
    end

    it "does not throttle /up health checks" do
      150.times { get "/up", headers: { "User-Agent" => "rspec-test" } }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "payments-specific throttle (20 POST / 60s)" do
    let(:headers) { { "User-Agent" => "rspec-test", "Content-Type" => "application/json" } }

    it "returns 429 on the 21st POST to /api/v1/payments from the same IP" do
      20.times { post "/api/v1/payments", params: "{}", headers: headers }

      post "/api/v1/payments", params: "{}", headers: headers

      expect(response.status).to eq(429)
    end
  end
end
