module Payments
  class CardProcessor < BaseProcessor
    FAILURE_CODES = %w[4000 4001 4002 4003 4004 4005 4006 4007 4008 4009].freeze

    def process
      response = simulate_gateway_call

      if response[:approved]
        record_attempt!(status: "approved", processor_response: response[:code])
        mark_succeeded!
      else
        record_attempt!(status: "declined", processor_response: response[:code])
        mark_failed!(response[:message])
      end
    end

    private

    def simulate_gateway_call
      card_number = payment.payment_details["card_number"].to_s

      if FAILURE_CODES.any? { |code| card_number.ends_with?(code) }
        { approved: false, code: "declined" , message: "Card declined" }
      else
        { approved: true, code: "approved" , message: "Payment approved" }
      end
    end
  end
end