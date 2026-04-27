require 'rails_helper'

RSpec.describe Payments::CreateService do
  let(:base_params) do
    {
      amount: 5000,
      currency: "USD",
      payment_method: "card",
      customer_email: "good@example.com",
      payment_details: { card_number: "4242424242424242" },
    }
  end

  describe "#call" do
    context "with a clean card payment" do
      before { allow_any_instance_of(Payments::CardProcessor).to receive(:process) }

      it "returns success and creates a payment" do
        expect {
          @result = described_class.new(params: base_params).call
        }.to change(Payment, :count).by(1)

        expect(@result).to be_success
        expect(@result.payload).to be_a(Payment)
      end

      it "persists the risk score from the assessor" do
        result = described_class.new(params: base_params).call
        expect(result.payload.risk_score).to eq(0)
      end

      it "invokes the CardProcessor synchronously" do
        expect_any_instance_of(Payments::CardProcessor).to receive(:process)
        described_class.new(params: base_params).call
      end
    end

    context "with a bank_transfer payment" do
      let(:params) { base_params.merge(payment_method: "bank_transfer") }

      it "enqueues ProcessPaymentJob and does not process synchronously" do
        expect {
          described_class.new(params: params).call
        }.to have_enqueued_job(Payments::ProcessPaymentJob)
      end

      it "returns the persisted payment in pending state" do
        result = described_class.new(params: params).call
        expect(result).to be_success
        expect(result.payload.status).to eq("pending")
      end
    end

    context "when fraud rules block the payment" do
      let(:blocked_params) do
        base_params.merge(amount: 600_000, customer_email: "x@tempmail.com")
      end

      it "returns failure with fraud reasons and creates no payment" do
        expect {
          @result = described_class.new(params: blocked_params).call
        }.not_to change(Payment, :count)

        expect(@result).to be_failure
        expect(@result.errors.first).to include("Payment blocked by fraud rules")
        expect(@result.errors.first).to include("very_high_amount")
      end

      it "does not call any processor" do
        expect_any_instance_of(Payments::CardProcessor).not_to receive(:process)
        described_class.new(params: blocked_params).call
      end
    end

    context "with idempotency key" do
      before { allow_any_instance_of(Payments::CardProcessor).to receive(:process) }

      it "stores the key after a successful create" do
        expect {
          described_class.new(params: base_params, idempotency_key: "key-123").call
        }.to change(IdempotencyKey, :count).by(1)
      end

      it "returns a cached response on duplicate request and creates no new payment" do
        described_class.new(params: base_params, idempotency_key: "key-abc").call

        expect {
          @result = described_class.new(params: base_params, idempotency_key: "key-abc").call
        }.not_to change(Payment, :count)

        expect(@result).to be_cached
        expect(@result.payload).to include("id", "status")
      end

      it "ignores expired idempotency keys" do
        described_class.new(params: base_params, idempotency_key: "key-old").call
        IdempotencyKey.find_by(key: "key-old").update!(expires_at: 1.hour.ago)

        expect {
          described_class.new(params: base_params, idempotency_key: "key-old").call
        }.to change(Payment, :count).by(1)
      end
    end

    context "with invalid params" do
      it "returns failure with validation errors" do
        result = described_class.new(params: base_params.merge(currency: "EUR")).call
        expect(result).to be_failure
        expect(result.errors.join).to match(/currency/i)
      end

      it "does not enqueue the bank_transfer job on validation failure" do
        params = base_params.merge(payment_method: "bank_transfer", amount: -10)
        expect {
          described_class.new(params: params).call
        }.not_to have_enqueued_job(Payments::ProcessPaymentJob)
      end
    end
  end
end
