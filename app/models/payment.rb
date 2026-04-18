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
      after { update!(captured_at: Time.current) }
    end

    event :fail do
      transitions from: %i[pending authorized], to: :failed
      after { update!(failed_at: Time.current) }
    end
  end

  validates :amount, numericality: { greater_than: 0 }, presence: true
  validates :currency, inclusion: { in: CURRENCIES }, presence: true
  validates :customer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :payment_method, inclusion: { in: Payment::PAYMENT_METHODS }, presence: true

  has_many :payment_attempts, dependent: :destroy
  has_many :webhook_deliveries, dependent: :destroy
end