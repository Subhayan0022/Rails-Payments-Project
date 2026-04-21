module Webhooks
  class SignatureService
    def self.sign(payload)
      OpenSSL::HMAC.hexdigest(
        "SHA256",
        ENV.fetch("WEBHOOK_SECRET"),
        payload
      )
    end

    def self.verify(payload, signature)
      expected_signature = sign(payload)
      ActiveSupport::SecurityUtils.secure_compare(expected_signature, signature.to_s)
    end
  end
end