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

    context "with a high amount" do
      it "adds 30 points for amount over 100,000" do
        result = described_class.call(base_params.merge(amount: 150_000))
        expect(result[:score]).to eq(30)
        expect(result[:reasons]).to include("high_amount")
      end
      it "adds 50 points for amount over 500,000" do
        result = described_class.call(base_params.merge(amount: 600_000))
        expect(result[:score]).to eq(50)
        expect(result[:reasons]).to include("very_high_amount")
      end
    end

    context "with a disposable email" do
      it 'adds 40 points' do
        result = described_class.call(base_params.merge(customer_email: "fake@mailinator.com"))
        expect(result[:score]).to eq(40)
        expect(result[:reasons]).to include("disposable_email")
      end
    end

    context "with a card ending in 0000" do
      it 'adds 20 points' do
        params = base_params.merge(payment_details: { card_number: "4242424242420000" })
        result = described_class.call(params)
        expect(result[:score]).to eq(20)
        expect(result[:reasons]).to include("test_card_suffix")
      end
    end

    context "velocity check" do
      it "adds 50 points when 3+ recent payments exist for the same email" do
        email = "spammer@example.com"
        3.times { create(:payment, customer_email: email) }
        result = described_class.call(base_params.merge(customer_email: email))
        expect(result[:reasons]).to include("velocity_exceeded")
      end

      it "does not flag if only 2 recent payments exist" do
        email = "normal@example.com"
        2.times { create(:payment, customer_email: email) }
        result = described_class.call(base_params.merge(customer_email: email))
        expect(result[:reasons]).not_to include("velocity_exceeded")
      end

      it "ignores payments older than the velocity window" do
        email = "old@example.com"
        Timecop.freeze(15.minutes.ago) do
          3.times { create(:payment, customer_email: email) }
        end
        result = described_class.call(base_params.merge(customer_email: email))
        expect(result[:reasons]).not_to include("velocity_exceeded")
      end
    end

    context "blocking threshold" do
      it "marks blocked: true when score >= 75" do
        params = base_params.merge(amount: 600_000, customer_email: "x@tempmail.com")
        result = described_class.call(params)
        expect(result[:blocked]).to be true
      end

      it "marks blocked: false when score is 70 (just below threshold)" do
        params = base_params.merge(amount: 150_000, customer_email: "x@mailinator.com")
        result = described_class.call(params)
        expect(result[:score]).to eq(70)
        expect(result[:blocked]).to be false
      end
    end

    context "with missing optional fields" do
      it "does not crash when customer_email is missing" do
        expect { described_class.call(base_params.except(:customer_email)) }.not_to raise_error
      end

      it "does not crash when payment_details is missing" do
        result = described_class.call(base_params.except(:payment_details))
        expect(result[:reasons]).not_to include("test_card_suffix")
      end
    end
  end
end

