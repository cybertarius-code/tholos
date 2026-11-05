FactoryBot.define do
  factory :user do
    email_address { "user@example.com" }
    password { "password1234" }
  end

  trait :invalid_user do
    email_address { "invalid@example.com" }
    password { "invalidpassword" }
  end
end
