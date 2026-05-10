require 'rails_helper'

RSpec.describe "Api::V1::Metrics", type: :request do
  let(:headers) { { "User-Agent" => "rspec-test" } }

  describe "GET /api/v1/metrics" do
    it "returns zeroed metrics when no payments exist" do
      get "/api/v1/metrics", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["window"]).to eq("all")
      expect(body["payments"]["total"]).to eq(0)
      expect(body["payments"]["by_status"]).to eq({})
      expect(body["payments"]["success_rate"]).to be_nil
      expect(body["volume_captured"]).to eq({})
      expect(body["webhooks"]["by_status"]).to eq({})
      expect(body["generated_at"]).to be_present
    end

    it "aggregates payment counts by status and success rate" do
      create(:payment, status: "captured", amount: 1000, currency: "USD")
      create(:payment, status: "captured", amount: 2500, currency: "USD")
      create(:payment, status: "captured", amount: 700,  currency: "INR")
      create(:payment, status: "failed",   amount: 5000, currency: "USD")
      create(:payment, status: "pending",  amount: 100,  currency: "USD")

      get "/api/v1/metrics", headers: headers

      body = JSON.parse(response.body)
      expect(body["payments"]["total"]).to eq(5)
      expect(body["payments"]["by_status"]).to eq(
        "captured" => 3, "failed" => 1, "pending" => 1
      )
      # 3 captured / (3 captured + 1 failed) = 0.75
      expect(body["payments"]["success_rate"]).to eq(0.75)
      expect(body["volume_captured"]).to eq("USD" => "3500.0", "INR" => "700.0")
    end

    it "groups webhook deliveries by status" do
      payment = create(:payment, status: "captured")
      create(:webhook_delivery, payment: payment, status: "delivered")
      create(:webhook_delivery, payment: payment, status: "delivered")
      create(:webhook_delivery, payment: payment, status: "failed")

      get "/api/v1/metrics", headers: headers

      body = JSON.parse(response.body)
      expect(body["webhooks"]["by_status"]).to eq("delivered" => 2, "failed" => 1)
    end

    context "with a window param" do
      it "scopes results to the window" do
        Timecop.freeze(Time.current) do
          create(:payment, status: "captured", amount: 1000, currency: "USD", created_at: 2.hours.ago)
          create(:payment, status: "captured", amount: 2000, currency: "USD", created_at: 30.minutes.ago)

          get "/api/v1/metrics", params: { window: "1h" }, headers: headers

          body = JSON.parse(response.body)
          expect(body["window"]).to eq("1h")
          expect(body["payments"]["total"]).to eq(1)
          expect(body["volume_captured"]).to eq("USD" => "2000.0")
        end
      end

      it "ignores unknown window values and reports 'all'" do
        create(:payment, status: "captured", amount: 1000, currency: "USD", created_at: 10.days.ago)

        get "/api/v1/metrics", params: { window: "bogus" }, headers: headers

        body = JSON.parse(response.body)
        expect(body["window"]).to eq("all")
        expect(body["payments"]["total"]).to eq(1)
      end
    end
  end
end
