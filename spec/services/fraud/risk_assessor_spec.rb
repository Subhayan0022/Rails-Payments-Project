require 'rails_helper'

RSpec.describe Fraud::RiskAssessor do
  describe ".call" do
    let(:base_params) do
      {
        amount: 5000,
        currency: "USD",
        payment_method: "card",
        customer_email: "good@example.com",
        payment_details: { card_number: "4242424242424242" },
      }
    end

    context "with a clean payment" do
      it "returns score 0 and not blocked" do
        result = described_class.call(base_params)
        expect(result[:score]).to eq(0)
        expect(result[:reasons]).to be_empty
        expect(result[:blocked]).to be false
      end
    end
  end
end

