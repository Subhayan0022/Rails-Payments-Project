module Api
  module V1
    class MetricsController < ApplicationController
      WINDOWS = {
        "1h"  => 1.hour,
        "24h" => 24.hours,
        "7d"  => 7.days,
        "30d" => 30.days
      }.freeze

      def index
        scope = scoped_payments
        statuses = scope.group(:status).count

        captured = scope.where(status: "captured")
        volume = captured.group(:currency).sum("amount::numeric").transform_values(&:to_s)

        webhooks = scoped_webhooks.group(:status).count

        total = statuses.values.sum
        succeeded = statuses["captured"].to_i
        terminal = succeeded + statuses["failed"].to_i
        success_rate = terminal.zero? ? nil : (succeeded.to_f / terminal).round(4)

        render json: {
          window: window_label,
          payments: {
            total: total,
            by_status: statuses,
            success_rate: success_rate
          },
          volume_captured: volume,
          webhooks: {
            by_status: webhooks
          },
          generated_at: Time.current.iso8601
        }
      end

      private

      def scoped_payments
        apply_window(Payment.all)
      end

      def scoped_webhooks
        apply_window(WebhookDelivery.all)
      end

      def apply_window(relation)
        return relation unless window_duration

        relation.where("created_at >= ?", window_duration.ago)
      end

      def window_duration
        WINDOWS[params[:window]]
      end

      def window_label
        params[:window].presence_in(WINDOWS.keys) || "all"
      end
    end
  end
end
