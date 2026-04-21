module Payments
  class ProcessPaymentJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(payment_id)
      payment = Payment.find(payment_id)

      return unless payment.pending? # idempotency guard here. No re-process.

      Payments::BankTransferProcessor.new(payment).process
    end
  end
end