# This is the base processor for both Payments methods (as of now: Card or BankTransfer)

module Payments
  class BaseProcessor
    attr_reader :payment

    def initialize(payment)
      @payment = payment
    end

    def process
      raise NotImplementedError, "subclasses of Payments::Base must implement #process"
    end

    private

    def record_attempt!(status:, processor_response: nil, metadata: {})
      PaymentAttempt.create!(
        payment: payment,
        status: status,
        processor_response: processor_response,
        metadata: metadata,
        attempt_number: payment.payment_attempts.count + 1
      )
    end

    def mark_succeeded!
      payment.authorize! if payment.may_authorize?
      payment.capture! if payment.may_capture?
    end

    def mark_failed!(reason)
      payment.update!(failure_reason: reason)
      payment.fail! if payment.may_fail?
    end
  end
end