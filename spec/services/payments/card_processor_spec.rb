require 'rails_helper'

RSpec.describe Payments::CardProcessor do
  let(:approved_payment) do
    create(:payment, payment_details: { "card_number" => "4242424242424242" })
  end
  let(:declined_payment) do
    create(:payment, payment_details: { "card_number" => "4111111111114000" })
  end

  describe "#process" do
    context "with an approved card" do
      it "transitions the payment to captured" do
        described_class.new(approved_payment).process
        expect(approved_payment.reload.status).to eq("captured")
      end

      it "stamps authorized_at and captured_at" do
        described_class.new(approved_payment).process
        approved_payment.reload
        expect(approved_payment.authorized_at).to be_present
        expect(approved_payment.captured_at).to be_present
      end

      it "creates an approved payment_attempt" do
        expect {
          described_class.new(approved_payment).process
        }.to change(approved_payment.payment_attempts, :count).by(1)

        attempt = approved_payment.payment_attempts.last
        expect(attempt.status).to eq("approved")
        expect(attempt.processor_response).to eq("approved")
        expect(attempt.attempt_number).to eq(1)
      end
    end

    context "with a declined card" do
      it "transitions the payment to failed" do
        described_class.new(declined_payment).process
        expect(declined_payment.reload.status).to eq("failed")
      end

      it "records the failure reason" do
        described_class.new(declined_payment).process
        expect(declined_payment.reload.failure_reason).to eq("Card declined")
        expect(declined_payment.failed_at).to be_present
      end

      it "creates a declined payment_attempt" do
        described_class.new(declined_payment).process
        attempt = declined_payment.payment_attempts.last
        expect(attempt.status).to eq("declined")
        expect(attempt.processor_response).to eq("declined")
      end

      it "declines for any FAILURE_CODES suffix" do
        Payments::CardProcessor::FAILURE_CODES.each do |code|
          payment = create(:payment, payment_details: { "card_number" => "411111111111#{code}" })
          described_class.new(payment).process
          expect(payment.reload.status).to eq("failed"), "expected failure for suffix #{code}"
        end
      end
    end
  end
end
