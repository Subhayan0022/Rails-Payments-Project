require 'rails_helper'

RSpec.describe Webhooks::DeliverWebhookJob do
  let(:payment)  { create(:payment) }
  let(:delivery) { create(:webhook_delivery, payment: payment) }

  describe "#perform" do
    it "is a no-op when the delivery is already marked delivered" do
      delivery.update!(status: "delivered")
      expect(Webhooks::DeliveryService).not_to receive(:new)

      described_class.new.perform(delivery.id)
    end

    it "calls DeliveryService and does not raise on a successful response" do
      response = instance_double(Faraday::Response, success?: true)
      service  = instance_double(Webhooks::DeliveryService, call: response)
      allow(Webhooks::DeliveryService).to receive(:new).with(delivery).and_return(service)

      expect {
        described_class.new.perform(delivery.id)
      }.not_to raise_error
    end

    it "raises when the response is not successful so retries fire" do
      response = instance_double(Faraday::Response, success?: false, status: 500, body: "boom")
      service  = instance_double(Webhooks::DeliveryService, call: response)
      allow(Webhooks::DeliveryService).to receive(:new).with(delivery).and_return(service)

      expect {
        described_class.new.perform(delivery.id)
      }.to raise_error(/Webhook failed/)
    end

    it "raises RecordNotFound when the delivery does not exist" do
      expect {
        described_class.new.perform("missing-id")
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
