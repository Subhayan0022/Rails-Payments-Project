require 'rails_helper'

RSpec.describe Merchant, type: :model do
  describe "validations" do
    subject { build(:merchant) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }

    it "rejects malformed emails" do
      expect(build(:merchant, email: "not-an-email")).not_to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:api_keys).dependent(:destroy) }
    it { is_expected.to have_many(:payments).dependent(:restrict_with_exception) }
    it { is_expected.to have_many(:idempotency_keys).dependent(:destroy) }
  end

  describe ".active" do
    it "returns only active merchants" do
      active   = create(:merchant, active: true)
      inactive = create(:merchant, active: false)

      expect(Merchant.active).to include(active)
      expect(Merchant.active).not_to include(inactive)
    end
  end
end
