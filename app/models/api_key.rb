require "securerandom"
require "digest"

class ApiKey < ApplicationRecord
  PREFIX = "pk_live_".freeze
  TOKEN_BYTES = 24

  belongs_to :merchant

  validates :key_hash, presence: true, uniqueness: true
  validates :key_prefix, :last4, presence: true

  scope :active, -> { where(revoked_at: nil) }

  Generated = Struct.new(:record, :plaintext, keyword_init: true) do
    def masked
      "#{record.key_prefix}...#{record.last4}"
    end
  end

  class << self
    def generate!(merchant:, name: nil)
      plaintext = "#{PREFIX}#{SecureRandom.hex(TOKEN_BYTES)}"
      record = create!(
        merchant: merchant,
        name: name,
        key_hash: hash_token(plaintext),
        key_prefix: PREFIX.chomp("_"),
        last4: plaintext.last(4)
      )
      Generated.new(record: record, plaintext: plaintext)
    end

    def authenticate(plaintext)
      return nil if plaintext.blank?

      key = active.find_by(key_hash: hash_token(plaintext))
      return nil unless key
      return nil unless key.merchant.active?

      key.touch(:last_used_at)
      key
    end

    def hash_token(plaintext)
      Digest::SHA256.hexdigest(plaintext)
    end
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end
end
