# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'virtual attributes' do
    let(:user) { FactoryBot.create(:user, :confirmed) }
    let(:another_user) { FactoryBot.create(:user, :confirmed) }

    describe '#credit_limit' do
      it 'defaults to `BentOS::Config.accounting.default_credit_limit_amount`' do
        expect(user.credit_limit).to eq(
          Money.from_amount(BentOS::Config.accounting.default_credit_limit_amount)
        )
      end

      it 'can be set to a custom value per user' do
        custom_credit_limit = Money.from_amount(123_456_789.0)
        user.credit_limit = custom_credit_limit
        expect(user.credit_limit).to eq(custom_credit_limit)

        # credit_limit should be persisted
        user.save!
        user.reload
        expect(user.credit_limit).to eq(custom_credit_limit)

        # Setting the credit_limit for a user will not affect other users
        expect(another_user.credit_limit).to eq(
          Money.from_amount(BentOS::Config.accounting.default_credit_limit_amount)
        )
      end
    end
  end

  describe 'relations' do
    it { is_expected.to have_many(:oauth_authentications) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_numericality_of(:credit_limit).is_greater_than(0) }
  end

  describe '#from_oauth_authentication' do
    subject { User.from_oauth_authentication(oauth_authentication) }

    context 'without existing user' do
      let(:oauth_authentication) { create(:user_oauth_authentication) }

      it 'builds a new confirmed user without saving' do
        expect(subject).to have_attributes(
          name: oauth_authentication.user_name,
          email: oauth_authentication.user_email,
          picture_url: oauth_authentication.user_picture_url
        )
        expect(subject).to be_confirmed
        expect(subject).not_to be_persisted
        # expect subject.oauth_authentications contains oauth_authentication?
      end

      it 'assigns the new user to the oauth_authentication and set sync_data to true without saving' do
        expect { subject }.to change { oauth_authentication.user }.from(nil)
        expect(oauth_authentication.user).to be(subject)
        expect(oauth_authentication.sync_data).to be(true)
      end
    end

    context 'with existing user' do
      let(:oauth_authentication) { create(:user_oauth_authentication, :with_user) }

      it 'returns the existing user without modification' do
        expect(subject).to be(oauth_authentication.user)
        expect(subject).to be_persisted
        expect(subject).not_to be_changed
      end

      context 'sync_data is on' do
        let(:oauth_authentication) { create(:user_oauth_authentication, :with_user, :sync_data) }
        it 'returns the existing user with data updated and confirmed without saving' do
          expect(subject).to have_attributes(
            name: oauth_authentication.user_name,
            email: oauth_authentication.user_email,
            picture_url: oauth_authentication.user_picture_url
          )
          expect(subject).to be_persisted
          expect(subject).to be_confirmed
          expect(subject.changed).to contain_exactly('name', 'email', 'picture_url')
        end
      end
    end
  end
end
