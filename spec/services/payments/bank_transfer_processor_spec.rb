require 'rails_helper'

RSpec.describe Payments::BankTransferProcessor do
  let(:payment) { create(:payment, payment_method: "bank_transfer") }

  describe "#process" do
    context "when the bank approves" do
      before do
        allow_any_instance_of(described_class).to receive(:rand).and_return(0.99)
      end

      it "transitions the payment to captured" do
        described_class.new(payment).process
        expect(payment.reload.status).to eq("captured")
      end

      it "records an approved payment_attempt" do
        expect {
          described_class.new(payment).process
        }.to change(payment.payment_attempts, :count).by(1)

        attempt = payment.payment_attempts.last
        expect(attempt.status).to eq("approved")
        expect(attempt.processor_response).to eq("settled")
      end
    end

    context "when the bank declines" do
      before do
        allow_any_instance_of(described_class).to receive(:rand).and_return(0.01)
      end

      it "transitions the payment to failed and stores the failure reason" do
        described_class.new(payment).process
        payment.reload
        expect(payment.status).to eq("failed")
        expect(payment.failure_reason).to eq("Bank transfer failed")
      end

      it "records a declined payment_attempt" do
        described_class.new(payment).process
        attempt = payment.payment_attempts.last
        expect(attempt.status).to eq("declined")
        expect(attempt.processor_response).to eq("bank_error")
      end
    end
  end
end
