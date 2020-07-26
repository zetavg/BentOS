FactoryBot.define do
  factory :user_oauth_authentication, class: 'User::OAuthAuthentication' do
    provider { 'google_oauth2' }
    uid { SecureRandom.hex(64) }
    data do
      first_name = Faker::Name.first_name
      last_name = Faker::Name.last_name

      {
        name: "#{first_name} #{last_name}",
        first_name: first_name,
        last_name: last_name,
        email: Faker::Internet.email,
        email_verified: true,
        image: Faker::Avatar.image
      }
    end

    trait :with_user do
      association :user, :confirmed
    end

    trait :sync_data do
      sync_data { true }
    end
  end
end
