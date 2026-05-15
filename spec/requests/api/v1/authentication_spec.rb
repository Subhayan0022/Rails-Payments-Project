require 'rails_helper'

RSpec.describe "Api::V1 authentication", type: :request do
  let(:merchant)  { create(:merchant) }
  let(:generated) { ApiKey.generate!(merchant: merchant) }
  let(:base_headers) { { "User-Agent" => "rspec-test" } }

  describe "GET /api/v1/metrics" do
    it "returns 401 when the Authorization header is missing" do
      get "/api/v1/metrics", headers: base_headers
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("Unauthorized")
    end

    it "returns 401 when the Authorization header is malformed" do
      get "/api/v1/metrics", headers: base_headers.merge("Authorization" => "Token abc")
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when the bearer token is unknown" do
      get "/api/v1/metrics", headers: base_headers.merge("Authorization" => "Bearer pk_live_nope")
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when the key is revoked" do
      generated.record.revoke!
      get "/api/v1/metrics", headers: auth_headers(generated.plaintext, base_headers)
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when the merchant is inactive" do
      merchant.update!(active: false)
      get "/api/v1/metrics", headers: auth_headers(generated.plaintext, base_headers)
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 200 with a valid bearer token" do
      get "/api/v1/metrics", headers: auth_headers(generated.plaintext, base_headers)
      expect(response).to have_http_status(:ok)
    end
  end
end
