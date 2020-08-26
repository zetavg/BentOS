# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.email }

    trait :confirmed do
      after(:build, &:skip_confirmation!)
    end

    trait :with_account_balance do
      transient do
        account_balance { 10_000 }
      end

      after(:create) do |user, evaluator|
        if evaluator.account_balance.positive?
          Accounting::UserDeposit.new(user: user, amount: evaluator.account_balance).save!
        else
          DoubleEntry.transfer Money.from_amount(-evaluator.account_balance),
                               code: :user_transfer,
                               from: user.account,
                               to: FactoryBot.create(:user, :confirmed).account
        end
      end
    end
  end
end
