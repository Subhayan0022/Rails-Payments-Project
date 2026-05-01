require 'rails_helper'

RSpec.describe Webhooks::SignatureService do
  let(:payload) { '{"event":"payment.succeeded","id":"pmt_123"}' }

  around do |example|
    original = ENV["WEBHOOK_SECRET"]
    ENV["WEBHOOK_SECRET"] = "test-secret"
    example.run
    ENV["WEBHOOK_SECRET"] = original
  end

  describe ".sign" do
    it "returns a 64-character hex SHA256 digest" do
      signature = described_class.sign(payload)
      expect(signature).to match(/\A[a-f0-9]{64}\z/)
    end

    it "is deterministic for the same payload and secret" do
      expect(described_class.sign(payload)).to eq(described_class.sign(payload))
    end

    it "produces different signatures for different payloads" do
      expect(described_class.sign(payload)).not_to eq(described_class.sign(payload + "x"))
    end

    it "produces different signatures when the secret changes" do
      original = described_class.sign(payload)
      ENV["WEBHOOK_SECRET"] = "different-secret"
      expect(described_class.sign(payload)).not_to eq(original)
    end
  end

  describe ".verify" do
    it "returns true for a matching signature" do
      signature = described_class.sign(payload)
      expect(described_class.verify(payload, signature)).to be true
    end

    it "returns false when the payload has been tampered with" do
      signature = described_class.sign(payload)
      tampered = payload.sub("pmt_123", "pmt_999")
      expect(described_class.verify(tampered, signature)).to be false
    end

    it "returns false for an incorrect signature" do
      expect(described_class.verify(payload, "deadbeef" * 8)).to be false
    end

    it "returns false when signature is nil" do
      expect(described_class.verify(payload, nil)).to be false
    end

    it "returns false when signature is empty" do
      expect(described_class.verify(payload, "")).to be false
    end
  end
end
