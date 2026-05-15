require 'rails_helper'

RSpec.describe "Api::V1 tenant isolation", type: :request do
  let(:merchant_a) { create(:merchant) }
  let(:merchant_b) { create(:merchant) }
  let(:token_a)    { ApiKey.generate!(merchant: merchant_a).plaintext }
  let(:token_b)    { ApiKey.generate!(merchant: merchant_b).plaintext }

  let(:base_headers) { { "Content-Type" => "application/json", "User-Agent" => "rspec-test" } }
  let(:valid_payload) do
    {
      payment: {
        amount: 5000,
        currency: "USD",
        payment_method: "card",
        customer_email: "good@example.com",
        payment_details: { card_number: "4242424242424242" },
      }
    }.to_json
  end

  it "prevents merchant B from fetching merchant A's payment" do
    payment = create(:payment, merchant: merchant_a, status: "captured")

    get "/api/v1/payments/#{payment.id}", headers: auth_headers(token_b, base_headers)

    expect(response).to have_http_status(:not_found)
  end

  it "allows the same idempotency key string across different merchants" do
    headers_a = auth_headers(token_a, base_headers).merge("Idempotency-Key" => "shared-key")
    headers_b = auth_headers(token_b, base_headers).merge("Idempotency-Key" => "shared-key")

    post "/api/v1/payments", params: valid_payload, headers: headers_a
    expect(response).to have_http_status(:created)
    id_a = JSON.parse(response.body)["id"]

    post "/api/v1/payments", params: valid_payload, headers: headers_b
    expect(response).to have_http_status(:created)
    id_b = JSON.parse(response.body)["id"]

    expect(id_a).not_to eq(id_b)
  end

  it "scopes metrics to the calling merchant" do
    create(:payment, merchant: merchant_a, status: "captured", amount: 1000, currency: "USD")
    create(:payment, merchant: merchant_b, status: "captured", amount: 9999, currency: "USD")

    get "/api/v1/metrics", headers: auth_headers(token_a, { "User-Agent" => "rspec-test" })

    body = JSON.parse(response.body)
    expect(body["payments"]["total"]).to eq(1)
    expect(body["volume_captured"]).to eq("USD" => "1000.0")
  end
end
