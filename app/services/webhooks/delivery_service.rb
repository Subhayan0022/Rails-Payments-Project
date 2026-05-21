module Webhooks
  class DeliveryService
    attr_reader :delivery

    def initialize(delivery)
      @delivery = delivery
    end

    def call
      payload = build_payload
      signature = SignatureService.sign(payload.to_json)

      response = Faraday.post(delivery.endpoint_url) do |req|
        req.headers['Content-Type'] = 'application/json'
        req.headers["X-Webhook-Signature"] = signature
        req.headers["X-Webhook-Event"] = delivery.event_type
        req.body = payload.to_json
      end

      record_result!(response)
      response

    rescue Faraday::Error => e
      record_error!(e.message)
      raise
    end

    private

    def build_payload
      payment = delivery.payment
      {
        event: delivery.event_type,
        delivered_at: Time.current.iso8601,
        data: {
          id: payment.id,
          status: payment.status,
          amount: payment.amount,
          currency: payment.currency,
          payment_method: payment.payment_method,
          customer_email: payment.customer_email,
        }
      }
    end

    def record_result!(response)
      delivery.attempt_number += 1
      delivery.update!(
        response_status: response.status,
        response_body: response.body.to_s[0, 2000], # 2000 char limit
        status: response.success? ? "delivered" : "failed",
        error_message: response.success? ? nil : "HTTP #{response.status}",
        next_retry_at: response.success? ? nil : delivery.backoff_until
      )
    end

    def record_error!(error_message)
      delivery.attempt_number += 1
      delivery.update!(
        status: "failed",
        error_message: error_message,
        next_retry_at: delivery.backoff_until
      )
    end
  end
end