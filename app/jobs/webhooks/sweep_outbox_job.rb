module Webhooks
  class SweepOutboxJob < ApplicationJob
    queue_as :low

    BATCH_SIZE = 500

    def perform
      WebhookDelivery.exhausted.in_batches(of: BATCH_SIZE) do |batch|
        batch.update_all(status: "exhausted", next_retry_at: nil, updated_at: Time.current)
      end

      requeued = 0
      WebhookDelivery.retriable.in_batches(of: BATCH_SIZE) do |batch|
        batch.each do |delivery|
          Webhooks::DeliverWebhookJob.perform_later(delivery.id)
          requeued += 1
        end
      end

      requeued
    end
  end
end
