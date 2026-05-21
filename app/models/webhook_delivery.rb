class WebhookDelivery < ApplicationRecord
  belongs_to :payment

  # After this many attempts a delivery is considered exhausted and is no longer
  # retried by the outbox sweeper.
  MAX_ATTEMPTS = 8

  validates :event_type,   presence: true
  validates :endpoint_url, presence: true
  validates :status,       presence: true

  scope :pending,  -> { where(status: "pending") }
  scope :failed,   -> { where(status: "failed") }
  scope :due,      -> { where("next_retry_at <= ?", Time.current) }

  scope :retriable, lambda {
    where(status: %w[pending failed])
      .where("attempt_number < ?", MAX_ATTEMPTS)
      .where("next_retry_at IS NULL OR next_retry_at <= ?", Time.current)
  }

  scope :exhausted, lambda {
    where(status: %w[pending failed]).where("attempt_number >= ?", MAX_ATTEMPTS)
  }

  # Exponential backoff (capped at 60 min) based on attempts made so far.
  def backoff_until(now = Time.current)
    minutes = [2**attempt_number, 60].min
    now + minutes.minutes
  end
end
