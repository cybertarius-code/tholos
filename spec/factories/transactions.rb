FactoryBot.define do
  factory :transaction do
    account
    household { account.household }
    currency { account.currency }
    amount_cents { -1_250 }
    date { Date.new(2026, 11, 20) }
    status { "cleared" }

    trait :income do
      amount_cents { 200_000 }
    end

    trait :scheduled do
      status { "scheduled" }
    end
  end
end
