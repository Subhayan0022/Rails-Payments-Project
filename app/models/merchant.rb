class Merchant < ApplicationRecord
  has_many :api_keys, dependent: :destroy
  has_many :payments, dependent: :restrict_with_exception
  has_many :idempotency_keys, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :active, -> { where(active: true) }
end
