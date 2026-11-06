FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "password1234" }

    trait :with_household do
      after(:create) { |user| create(:membership, user: user) }
    end
  end

  trait :invalid_user do
    email_address { "invalid@example.com" }
    password { "invalidpassword" }
  end
end
