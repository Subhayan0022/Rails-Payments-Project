class IdempotencyKey < ApplicationRecord
  belongs_to :merchant

  validates :key,             presence: true
  validates :request_path,    presence: true
  validates :response_status, presence: true
  validates :expires_at,      presence: true

  scope :unexpired, -> { where("expires_at > ?", Time.current) }
end
