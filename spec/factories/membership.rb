FactoryBot.define do
  factory :membership do
    association :user
    association :household
    role { "owner" }

    trait :member do
      role { "member" }
    end

    trait :invalid_membership do
      user { nil }
      household { nil }
      role { nil }
    end
  end
end
