FactoryBot.define do
  factory :category do
    household
    sequence(:name) { |n| "Categoría #{n}" }
    kind { "expense" }
    report_group { "essentials" }
    color { "navy" }
    icon { "tag" }

    trait :income do
      kind { "income" }
      report_group { nil }
    end

    trait :archived do
      archived_at { Time.current }
    end

    # Hija: hereda hogar y tipo del padre
    trait :child do
      parent { association :category, household: household }
      report_group { nil }
    end
  end
end
