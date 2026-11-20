FactoryBot.define do
  factory :account do
    household
    sequence(:name) { |n| "Cuenta #{n}" }
    kind { "checking" }
    currency { "EUR" }
    opening_balance_cents { 0 }
    opening_date { Date.new(2026, 1, 1) }

    trait :credit_card do
      kind { "credit_card" }
    end

    trait :closed do
      status { "closed" }
    end
  end
end
