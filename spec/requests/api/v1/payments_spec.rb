require 'rails_helper'

RSpec.describe "Api::V1::Payments", type: :request do
  let(:headers) do
    {
      "Content-Type" => "application/json",
      "User-Agent"   => "rspec-test",
    }
  end

  let(:valid_params) do
    {
      payment: {
        amount: 5000,
        currency: "USD",
        payment_method: "card",
        customer_email: "good@example.com",
        payment_details: { card_number: "4242424242424242" },
      }
    }
  end

  describe "POST /api/v1/payments" do
    context "with a valid card payment" do
      it "creates a captured payment and returns 201" do
        expect {
          post "/api/v1/payments", params: valid_params.to_json, headers: headers
        }.to change(Payment, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["status"]).to eq("captured")
        expect(body["amount"].to_i).to eq(5000)
        expect(body["captured_at"]).to be_present
      end
    end

    context "with a bank_transfer payment" do
      let(:bank_params) do
        valid_params.deep_merge(payment: { payment_method: "bank_transfer" })
      end

      it "creates a pending payment and enqueues the processing job" do
        expect {
          post "/api/v1/payments", params: bank_params.to_json, headers: headers
        }.to change(Payment, :count).by(1)
          .and have_enqueued_job(Payments::ProcessPaymentJob)

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)["status"]).to eq("pending")
      end
    end

    context "with an Idempotency-Key" do
      let(:idem_headers) { headers.merge("Idempotency-Key" => "key-xyz") }

      it "returns 200 with the cached body on the second call" do
        post "/api/v1/payments", params: valid_params.to_json, headers: idem_headers
        expect(response).to have_http_status(:created)
        original_id = JSON.parse(response.body)["id"]

        expect {
          post "/api/v1/payments", params: valid_params.to_json, headers: idem_headers
        }.not_to change(Payment, :count)

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["id"]).to eq(original_id)
      end
    end

    context "when fraud rules block the payment" do
      let(:blocked_params) do
        valid_params.deep_merge(payment: { amount: 600_000, customer_email: "x@tempmail.com" })
      end

      it "returns 422 with fraud reasons and creates no payment" do
        expect {
          post "/api/v1/payments", params: blocked_params.to_json, headers: headers
        }.not_to change(Payment, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["errors"].first).to include("Payment blocked by fraud rules")
      end
    end

    context "with invalid params" do
      it "returns 422 for an unsupported currency" do
        bad = valid_params.deep_merge(payment: { currency: "EUR" })
        post "/api/v1/payments", params: bad.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["errors"].join).to match(/currency/i)
      end

      it "returns 422 for a malformed email" do
        bad = valid_params.deep_merge(payment: { customer_email: "not-an-email" })
        post "/api/v1/payments", params: bad.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "without a User-Agent" do
      it "is blocked by Rack::Attack" do
        post "/api/v1/payments",
             params: valid_params.to_json,
             headers: { "Content-Type" => "application/json" }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/v1/payments/:id" do
    let(:payment) { create(:payment, status: "captured", captured_at: Time.current) }

    it "returns 200 with the serialized payment" do
      get "/api/v1/payments/#{payment.id}", headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(payment.id)
      expect(body["status"]).to eq("captured")
    end

    it "returns 404 when the payment does not exist" do
      get "/api/v1/payments/nonexistent-id", headers: headers
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to eq("Payment not found")
    end
  end
end
