require 'rails_helper'

RSpec.describe Payments::ProcessPaymentJob do
  let(:payment) { create(:payment, payment_method: "bank_transfer") }

  describe "#perform" do
    it "invokes BankTransferProcessor for a pending payment" do
      processor = instance_double(Payments::BankTransferProcessor, process: true)
      expect(Payments::BankTransferProcessor).to receive(:new).with(payment).and_return(processor)

      described_class.new.perform(payment.id)
    end

    it "is a no-op when the payment is no longer pending" do
      payment.update!(status: "captured")
      expect(Payments::BankTransferProcessor).not_to receive(:new)

      described_class.new.perform(payment.id)
    end

    it "raises when the payment does not exist" do
      expect {
        described_class.new.perform("does-not-exist")
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
