FactoryBot.define do
  factory :household do
    name { "Smith Family" }
    base_currency { "EUR" }
  end

  trait :invalid_household do
    name { "" }
    base_currency { "" }
  end
end
