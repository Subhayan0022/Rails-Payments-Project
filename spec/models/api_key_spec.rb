require 'rails_helper'

RSpec.describe ApiKey, type: :model do
  let(:merchant) { create(:merchant) }

  describe "associations" do
    it { is_expected.to belong_to(:merchant) }
  end

  describe ".generate!" do
    it "creates a key with prefix, last4, and a stored hash (not the plaintext)" do
      generated = ApiKey.generate!(merchant: merchant)

      expect(generated.plaintext).to start_with("pk_live_")
      expect(generated.record.key_prefix).to eq("pk_live")
      expect(generated.record.last4).to eq(generated.plaintext.last(4))
      expect(generated.record.key_hash).to eq(Digest::SHA256.hexdigest(generated.plaintext))
      expect(ApiKey.where(key_hash: generated.plaintext)).to be_empty
    end

    it "produces unique tokens across calls" do
      a = ApiKey.generate!(merchant: merchant).plaintext
      b = ApiKey.generate!(merchant: merchant).plaintext
      expect(a).not_to eq(b)
    end

    it "exposes a masked representation" do
      generated = ApiKey.generate!(merchant: merchant)
      expect(generated.masked).to eq("pk_live...#{generated.record.last4}")
    end
  end

  describe ".authenticate" do
    it "returns the key and touches last_used_at on a valid token" do
      generated = ApiKey.generate!(merchant: merchant)

      key = ApiKey.authenticate(generated.plaintext)

      expect(key).to eq(generated.record)
      expect(key.last_used_at).to be_present
    end

    it "returns nil for a blank token" do
      expect(ApiKey.authenticate(nil)).to be_nil
      expect(ApiKey.authenticate("")).to be_nil
    end

    it "returns nil for an unknown token" do
      expect(ApiKey.authenticate("pk_live_doesnotexist")).to be_nil
    end

    it "returns nil for a revoked key" do
      generated = ApiKey.generate!(merchant: merchant)
      generated.record.revoke!

      expect(ApiKey.authenticate(generated.plaintext)).to be_nil
    end

    it "returns nil when the merchant is inactive" do
      generated = ApiKey.generate!(merchant: merchant)
      merchant.update!(active: false)

      expect(ApiKey.authenticate(generated.plaintext)).to be_nil
    end
  end

  describe "#revoke!" do
    it "stamps revoked_at" do
      key = ApiKey.generate!(merchant: merchant).record
      expect { key.revoke! }.to change { key.reload.revoked_at }.from(nil)
      expect(key).to be_revoked
    end
  end
end
