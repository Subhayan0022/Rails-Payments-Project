module Payments
  class BankTransferProcessor < BaseProcessor
    # To simulate some error cases on this sandbox env we will try deliberately push fail cases sometimes.
    FAILURE_RATE = 0.3

    def process
      response = simulate_bank_call

      if response[:approved]
        record_attempt!(status: "approved", processor_response: response[:code])
        mark_succeeded!
      else
        record_attempt!(status: "declined", processor_response: response[:code])
        mark_failed!(response[:message])
      end
    end

    private

    def simulate_bank_call
      if rand < FAILURE_RATE
        { approved: false, code: "bank_error", message: "Bank transfer failed" }
      else
        { approved: true, code: "settled", message: "Bank transfer settled" }
      end
    end

  end
end