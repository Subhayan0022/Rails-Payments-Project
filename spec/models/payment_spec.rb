require 'rails_helper'

RSpec.describe Payment, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than(0) }
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_inclusion_of(:currency).in_array(Payment::CURRENCIES) }
    it { is_expected.to validate_presence_of(:payment_method) }
    it { is_expected.to validate_inclusion_of(:payment_method).in_array(Payment::PAYMENT_METHODS) }
    it { is_expected.to validate_presence_of(:customer_email) }

    it "rejects malformed emails" do
      payment = build(:payment, customer_email: "not-an-email")
      expect(payment).not_to be_valid
      expect(payment.errors[:customer_email]).to be_present
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:payment_attempts).dependent(:destroy) }
    it { is_expected.to have_many(:webhook_deliveries).dependent(:destroy) }
  end

  describe "AASM state machine" do
    let(:payment) { create(:payment) }

    it "starts in pending" do
      expect(payment.status).to eq("pending")
    end

    it "transitions pending → authorized and stamps authorized_at" do
      expect { payment.authorize! }.to change { payment.reload.status }.from("pending").to("authorized")
      expect(payment.authorized_at).to be_present
    end

    it "transitions authorized → captured and stamps captured_at" do
      payment.authorize!
      expect { payment.capture! }.to change { payment.reload.status }.to("captured")
      expect(payment.captured_at).to be_present
    end

    it "transitions pending → failed and stamps failed_at" do
      expect { payment.fail! }.to change { payment.reload.status }.to("failed")
      expect(payment.failed_at).to be_present
    end

    it "transitions authorized → failed" do
      payment.authorize!
      expect { payment.fail! }.to change { payment.reload.status }.to("failed")
    end

    it "raises on invalid transition (pending → captured)" do
      expect { payment.capture! }.to raise_error(AASM::InvalidTransition)
    end

    it "raises on transition from captured" do
      payment.authorize!
      payment.capture!
      expect { payment.fail! }.to raise_error(AASM::InvalidTransition)
    end
  end

  describe "webhook enqueue callbacks" do
    let(:payment) { create(:payment) }

    around do |example|
      original = ENV["WEBHOOK_ENDPOINT_URL"]
      ENV["WEBHOOK_ENDPOINT_URL"] = "https://example.test/hook"
      example.run
      ENV["WEBHOOK_ENDPOINT_URL"] = original
    end

    it "enqueues a payment.succeeded webhook on capture" do
      payment.authorize!
      expect {
        payment.capture!
      }.to have_enqueued_job(Webhooks::DeliverWebhookJob)

      delivery = payment.webhook_deliveries.last
      expect(delivery.event_type).to eq("payment.succeeded")
      expect(delivery.endpoint_url).to eq("https://example.test/hook")
      expect(delivery.status).to eq("pending")
    end

    it "enqueues a payment.failed webhook on fail" do
      expect {
        payment.fail!
      }.to have_enqueued_job(Webhooks::DeliverWebhookJob)

      expect(payment.webhook_deliveries.last.event_type).to eq("payment.failed")
    end

    it "does not enqueue or create a delivery row on authorize" do
      expect {
        payment.authorize!
      }.not_to have_enqueued_job(Webhooks::DeliverWebhookJob)
      expect(payment.webhook_deliveries).to be_empty
    end
  end

  describe "webhook enqueue when endpoint is blank" do
    let(:payment) { create(:payment) }

    around do |example|
      original = ENV["WEBHOOK_ENDPOINT_URL"]
      ENV["WEBHOOK_ENDPOINT_URL"] = nil
      example.run
      ENV["WEBHOOK_ENDPOINT_URL"] = original
    end

    it "skips webhook enqueue and creates no delivery row" do
      payment.authorize!
      expect {
        payment.capture!
      }.not_to have_enqueued_job(Webhooks::DeliverWebhookJob)
      expect(payment.webhook_deliveries).to be_empty
    end
  end
end
