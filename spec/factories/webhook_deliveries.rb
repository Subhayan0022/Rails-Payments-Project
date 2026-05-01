FactoryBot.define do
  factory :webhook_delivery do
    payment
    event_type     { "payment.succeeded" }
    endpoint_url   { "https://example.test/hook" }
    status         { "pending" }
    attempt_number { 0 }
  end
end
