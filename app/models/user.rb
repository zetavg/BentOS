# frozen_string_literal: true

class User < ApplicationRecord
  devise :database_authenticatable, :rememberable, :recoverable, :lockable,
         :registerable, :omniauthable, :validatable, :confirmable

  has_many :oauth_authentications, dependent: :destroy

  def self.from_oauth_authentication(oauth_authentication)
    user = oauth_authentication.user

    # Build a user if there isn't an exist one.
    unless user
      user = User.new(
        email: oauth_authentication.user_email,
        name: oauth_authentication.user_name
      )
      user.skip_confirmation! # since the email is already confirmed by the OAuth provider
      oauth_authentication.user = user
      oauth_authentication.sync_data = true
    end

    # Copy user data from oauth_authentication if sync_data is enabled.
    if oauth_authentication.sync_data
      user.name = oauth_authentication.user_name
      user.email = oauth_authentication.user_email
      user.picture_url = oauth_authentication.user_picture_url
    end

    user
  end

  def displayed_name
    name || email
  end

  protected

  def password_required?
    false
  end
end
