class WebhookDelivery < ApplicationRecord
  belongs_to :payment

  validates :event_type,   presence: true
  validates :endpoint_url, presence: true
  validates :status,       presence: true

  scope :pending,  -> { where(status: "pending") }
  scope :failed,   -> { where(status: "failed") }
  scope :due,      -> { where("next_retry_at <= ?", Time.current) }
end
