module Payments
  class CreateService
    attr_reader :params, :idempotency_key

    def initialize(params:, idempotency_key: nil)
      @params = params
      @idempotency_key = idempotency_key
    end
    def call
      return cached_response if duplicate_request?

      payment = create_payment!
      process_payment(payment)
      store_idempotency_key(payment) if idempotency_key.present?

      ServiceResult.success(payment)
    rescue ActiveRecord::RecordInvalid => e
      ServiceResult.failure(e.record.errors.full_messages)
    end

    private
    def duplicate_request?
      return false if idempotency_key.blank?
      @existing_key = IdempotencyKey.unexpired.find_by(key: idempotency_key)
      @existing_key.present?
    end

    def cached_response
      ServiceResult.cached(@existing_key.response_body)
    end

    def create_payment!
      Payment.create!(
        amount: params[:amount],
        currency: params[:currency] || "USD",
        payment_method: params[:payment_method],
        customer_email: params[:customer_email],
        customer_name: params[:customer_name],
        description: params[:description],
        payment_details: params[:payment_details] || {},
        idempotency_key: idempotency_key,
      )
    end

    def process_payment(payment)
      case payment.payment_method
      when "card"
        Payments::CardProcessor.new(payment).process

      when "bank_transfer"
        Payments::ProcessPaymentJob.perform_later(payment.id)
      end
    end

    def store_idempotency_key(payment)
      IdempotencyKey.create!(
        key: idempotency_key,
        request_path: "/api/v1/payments",
        response_body: { id: payment.id, status: payment.status },
        response_status: 201,
        expires_at: 24.hours.from_now
      )
    end
  end
end