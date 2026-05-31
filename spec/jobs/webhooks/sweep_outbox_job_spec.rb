require 'rails_helper'

RSpec.describe Webhooks::SweepOutboxJob do
  let(:payment) { create(:payment) }

  describe "#perform" do
    it "marks deliveries past MAX_ATTEMPTS as exhausted" do
      stuck = create(:webhook_delivery, payment: payment, status: "failed",
                                        attempt_number: WebhookDelivery::MAX_ATTEMPTS)

      described_class.new.perform

      expect(stuck.reload.status).to eq("exhausted")
      expect(stuck.next_retry_at).to be_nil
    end

    it "re-enqueues retriable deliveries whose next_retry_at is due" do
      due = create(:webhook_delivery, payment: payment, status: "failed",
                                      attempt_number: 2, next_retry_at: 1.minute.ago)

      expect {
        described_class.new.perform
      }.to have_enqueued_job(Webhooks::DeliverWebhookJob).with(due.id)
    end

    it "does not re-enqueue deliveries whose next_retry_at is in the future" do
      create(:webhook_delivery, payment: payment, status: "failed",
                                attempt_number: 2, next_retry_at: 10.minutes.from_now)

      expect {
        described_class.new.perform
      }.not_to have_enqueued_job(Webhooks::DeliverWebhookJob)
    end

    it "does not touch already-delivered rows" do
      delivered = create(:webhook_delivery, payment: payment, status: "delivered",
                                            attempt_number: 1)

      expect {
        described_class.new.perform
      }.not_to have_enqueued_job(Webhooks::DeliverWebhookJob)

      expect(delivered.reload.status).to eq("delivered")
    end
  end
end
