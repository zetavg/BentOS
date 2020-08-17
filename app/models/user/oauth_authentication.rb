# frozen_string_literal: true

class User::OAuthAuthentication < ApplicationRecord
  belongs_to :user, inverse_of: :oauth_authentications, optional: true # In some cases, such as the new OAuth authentication has a suspicious existing account, we will create the OAuthAuthentication record before linking it to an user

  validates :uid, uniqueness: { scope: :provider }

  def self.from_auth_hash(auth)
    oauth_authentication = find_or_initialize_by(provider: auth[:provider], uid: auth[:uid])

    case auth[:provider]
    when 'google_oauth2'
      oauth_authentication.access_token = auth.dig(:credentials, :token)
      oauth_authentication.refresh_token = auth.dig(:credentials, :refresh_token)
      credentials_expires_at = auth.dig(:credentials, :expires_at)
      oauth_authentication.access_token_expires_at = Time.zone.at(credentials_expires_at) if credentials_expires_at
      oauth_authentication.data = (auth[:info] || {}).merge(auth.dig(:extra, :raw_info) || {})
    else
      raise StandardError, "Unknown auth[:provider]: '#{auth[:provider]}'"
    end

    oauth_authentication
  end

  def displayed_provider_name
    case provider
    when 'google_oauth2'
      BentOS::Config.user_center.oauth.google.display_name || 'Google'
    end
  end

  def user_email
    case provider
    when 'google_oauth2'
      data['email']
    end
  end

  def user_name
    case provider
    when 'google_oauth2'
      data['name']
    end
  end

  def user_picture_url
    case provider
    when 'google_oauth2'
      data['image']
    end
  end
end
