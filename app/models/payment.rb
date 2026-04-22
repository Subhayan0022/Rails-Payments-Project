class Payment < ApplicationRecord
  include AASM

  PAYMENT_METHODS = %w[card bank_transfer].freeze
  CURRENCIES = %w[USD INR JPY].freeze

  aasm column: :status do
    state :pending, initial: true
    state :authorized
    state :captured
    state :failed

    event :authorize do
      transitions from: :pending, to: :authorized
      after { update!(authorized_at: Time.current) }
    end

    event :capture do
      transitions from: :authorized, to: :captured
      after do
        update!(captured_at: Time.current)
        enqueue_webhook("payment.succeeded")
      end
    end

    event :fail do
      transitions from: %i[pending authorized], to: :failed
      after do
        update!(failed_at: Time.current)
        enqueue_webhook("payment.failed")
      end
    end
  end

  validates :amount, numericality: { greater_than: 0 }, presence: true
  validates :currency, inclusion: { in: CURRENCIES }, presence: true
  validates :customer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :payment_method, inclusion: { in: Payment::PAYMENT_METHODS }, presence: true

  has_many :payment_attempts, dependent: :destroy
  has_many :webhook_deliveries, dependent: :destroy

  private

  def enqueue_webhook(event_type)
    endpoint = ENV["WEBHOOK_ENDPOINT_URL"]
    return if endpoint.blank?

    delivery = webhook_deliveries.create!(
      event_type:     event_type,
      endpoint_url:   endpoint,
      status:         "pending",
      attempt_number: 0
    )

    Webhooks::DeliverWebhookJob.perform_later(delivery.id)
  end
end