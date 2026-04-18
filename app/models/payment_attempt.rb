class PaymentAttempt < ApplicationRecord
  belongs_to :payment

  validates :status,         presence: true
  validates :attempt_number, presence: true, numericality: { greater_than: 0 }
end
