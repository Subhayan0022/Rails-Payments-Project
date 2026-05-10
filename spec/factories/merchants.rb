FactoryBot.define do
  factory :merchant do
    name  { "Some Random Company" }
    email { Faker::Internet.email }
    active { true }
  end
end
