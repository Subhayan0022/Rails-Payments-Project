module Webhooks
  class DeliverWebhookJob < ApplicationJob
    queue_as :webhooks

    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(delivery_id)
      delivery = WebhookDelivery.find(delivery_id)
      return if delivery.status == "delivered" # idempotency here

      response = Webhooks::DeliveryService.new(delivery).call
      raise "Webhook failed: HTTPS #{response.code}: #{response.message}" unless response.success?
    end
  end
end