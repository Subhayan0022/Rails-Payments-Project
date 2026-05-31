require 'rails_helper'

RSpec.describe PaymentAttempt, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:payment) }
  end

  describe "validations" do
    subject { build(:payment_attempt) }

    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:attempt_number) }
    it { is_expected.to validate_numericality_of(:attempt_number).is_greater_than(0) }
  end
end
