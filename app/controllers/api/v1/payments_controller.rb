module Api
  module V1
    class PaymentsController < ApplicationController
      def create
        result = Payments::CreateService.new(
          params: payment_params,
          idempotency_key: request.headers["Idempotency-Key"]
        ).call

        case result.type
        when :success
          render json: serialize(result.payload), status: :created
        when :cached
          render json: result.payload, status: :ok
        when :failure
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      def show
        payment = Payment.find(params[:id])
        render json: serialize(payment), status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Payment not found" }, status: :not_found
      end

      private

      def payment_params
        params.permit(
          :amount, :currency, :payment_method,
          :customer_email, :customer_name, :description,
          payment_details: {}
        )
      end

      def serialize(payment)
        {
          id: payment.id,
          status: payment.status,
          amount: payment.amount,
          currency: payment.currency,
          payment_method: payment.payment_method,
          customer_email: payment.customer_email,
          created_at: payment.created_at,
          authorized_at: payment.authorized_at,
          captured_at: payment.captured_at,
          failed_at: payment.failed_at,
          failure_reason: payment.failure_reason
        }
      end
    end
  end
end
