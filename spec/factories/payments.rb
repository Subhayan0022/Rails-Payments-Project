FactoryBot.define do
  factory :payment do
    amount { 5000 }
    currency { "USD" }
    payment_method { "card" }
    customer_email { Faker::Internet.email }
    status { "pending" }
  end
end