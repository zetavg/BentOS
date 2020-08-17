# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User::OAuthAuthentication, type: :model do
  describe 'relations' do
    it { is_expected.to belong_to(:user).optional }
  end

  describe 'validations' do
    subject { FactoryBot.create(:user_oauth_authentication) }
    it { is_expected.to validate_uniqueness_of(:uid).scoped_to(:provider) }
  end

  describe '#from_auth_hash' do
    subject { User::OAuthAuthentication.from_auth_hash(auth_hash) }
    let(:user_name) { 'John Smith' }
    let(:user_email) { 'john@example.com' }
    let(:user_picture_url) { 'https://lh4.googleusercontent.com/photo.jpg' }
    let(:access_token) { 'TOKEN' }
    let(:access_token_expires_at) { Time.zone.at(2.hours.from_now.to_i) }
    let(:refresh_token) { 'REFRESH_TOKEN' }

    context 'with Google OAuth2 auth_hash' do
      let(:auth_provider) { 'google_oauth2' }
      let(:auth_uid) { 'sample-uid' }
      let(:auth_hash) do
        {
          provider: auth_provider,
          uid: auth_uid,
          info: {
            name: user_name,
            email: user_email,
            image: user_picture_url
          },
          credentials: {
            token: access_token,
            expires_at: access_token_expires_at.to_i,
            refresh_token: refresh_token
          },
          extra: {
            raw_info: {
              name: user_name,
              picture: user_picture_url,
              locale: 'en',
              hd: 'company.com'
            }
          }
        }
      end

      context 'with no existing oauth_authentication' do
        it 'builds a new oauth_authentication without saving' do
          expect(subject).to have_attributes(
            provider: auth_provider,
            uid: auth_uid,
            access_token: access_token,
            access_token_expires_at: access_token_expires_at,
            refresh_token: refresh_token,
            user_email: user_email,
            user_name: user_name,
            user_picture_url: user_picture_url
          )
          expect(subject).not_to be_persisted
        end
      end

      context 'with existing oauth_authentication' do
        let!(:existing_oauth_authentication) do
          create(:user_oauth_authentication, provider: auth_provider, uid: auth_uid)
        end

        it 'loads the existing oauth_authentication and assigns updated attributes without saving' do
          expect(subject).to be_persisted
          expect(subject.id).to eq(existing_oauth_authentication.id)

          expect(subject).to have_attributes(
            provider: auth_provider,
            uid: auth_uid,
            access_token: access_token,
            access_token_expires_at: access_token_expires_at,
            refresh_token: refresh_token,
            user_email: user_email,
            user_name: user_name,
            user_picture_url: user_picture_url
          )

          expect(subject.changed).to contain_exactly('access_token', 'refresh_token', 'access_token_expires_at', 'data')
        end
      end
    end

    context 'with unknown auth_hash' do
      let(:auth_hash) do
        { provider: 'unknown_provider' }
      end

      it 'raises error' do
        expect { subject }.to raise_error("Unknown auth[:provider]: 'unknown_provider'")
      end
    end
  end
end
