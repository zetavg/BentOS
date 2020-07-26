FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.email }

    trait :confirmed do
      after(:build, &:skip_confirmation!)
    end
  end
end
