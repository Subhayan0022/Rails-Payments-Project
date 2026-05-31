FactoryBot.define do
  factory :payment_attempt do
    payment
    status         { "succeeded" }
    attempt_number { 1 }
  end
end
