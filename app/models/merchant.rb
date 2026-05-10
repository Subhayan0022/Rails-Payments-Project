class Merchant < ApplicationRecord
  has_many :api_keys, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :active, -> { where(active: true) }
end
