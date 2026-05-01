require 'rails_helper'

RSpec.describe Webhooks::DeliveryService do
  let(:payment)  { create(:payment) }
  let(:delivery) { create(:webhook_delivery, payment: payment, endpoint_url: "https://example.test/hook") }

  around do |example|
    original = ENV["WEBHOOK_SECRET"]
    ENV["WEBHOOK_SECRET"] = "test-secret"
    example.run
    ENV["WEBHOOK_SECRET"] = original
  end

  describe "#call" do
    context "on a 2xx response" do
      before do
        stub_request(:post, "https://example.test/hook")
          .to_return(status: 200, body: "ok")
      end

      it "marks the delivery as delivered" do
        described_class.new(delivery).call
        delivery.reload
        expect(delivery.status).to eq("delivered")
        expect(delivery.response_status).to eq(200)
        expect(delivery.attempt_number).to eq(1)
        expect(delivery.error_message).to be_nil
      end

      it "sends signature, event, and JSON body headers" do
        described_class.new(delivery).call
        expect(WebMock).to have_requested(:post, "https://example.test/hook")
          .with(headers: {
            "Content-Type" => "application/json",
            "X-Webhook-Event" => "payment.succeeded",
          })
          .with { |req| req.headers["X-Webhook-Signature"].match?(/\A[a-f0-9]{64}\z/) }
      end

      it "signs the exact body that is posted" do
        described_class.new(delivery).call
        expect(WebMock).to have_requested(:post, "https://example.test/hook").with { |req|
          expected = Webhooks::SignatureService.sign(req.body)
          req.headers["X-Webhook-Signature"] == expected
        }
      end

      it "includes the payment data in the payload" do
        described_class.new(delivery).call
        expect(WebMock).to have_requested(:post, "https://example.test/hook").with { |req|
          body = JSON.parse(req.body)
          body["event"] == "payment.succeeded" &&
            body.dig("data", "id") == payment.id &&
            body.dig("data", "amount") == payment.amount
        }
      end
    end

    context "on a non-2xx response" do
      before do
        stub_request(:post, "https://example.test/hook")
          .to_return(status: 500, body: "boom")
      end

      it "marks the delivery as failed with the http status" do
        described_class.new(delivery).call
        delivery.reload
        expect(delivery.status).to eq("failed")
        expect(delivery.response_status).to eq(500)
        expect(delivery.error_message).to eq("HTTP 500")
        expect(delivery.attempt_number).to eq(1)
      end

      it "returns the response (does not raise)" do
        expect { described_class.new(delivery).call }.not_to raise_error
      end
    end

    context "on a network error" do
      before do
        stub_request(:post, "https://example.test/hook").to_raise(Faraday::ConnectionFailed)
      end

      it "marks the delivery as failed and re-raises" do
        expect {
          described_class.new(delivery).call
        }.to raise_error(Faraday::ConnectionFailed)

        delivery.reload
        expect(delivery.status).to eq("failed")
        expect(delivery.attempt_number).to eq(1)
      end
    end

    context "on retry of a previously-attempted delivery" do
      before do
        delivery.update!(attempt_number: 2)
        stub_request(:post, "https://example.test/hook").to_return(status: 200)
      end

      it "increments attempt_number from the previous value" do
        described_class.new(delivery).call
        expect(delivery.reload.attempt_number).to eq(3)
      end
    end
  end
end
