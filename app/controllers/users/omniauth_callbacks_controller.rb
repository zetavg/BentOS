# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    @oauth_authentication = User::OAuthAuthentication.from_auth_hash(request.env['omniauth.auth'])
    # In the future, we might need to detect existing user accounts and ask if
    # the user wants to sign-in as their old account and link the new OAuth
    # account, instead of creating a new account directly.
    # unless @oauth_authentication.user.present?
    #   possible_existing_accounts = ...
    #   unless possible_existing_accounts.blank?
    #     session['possible_existing_account_ids'] = possible_existing_account_ids.map(&:id)
    #     session['pending_oauth_authentication_id'] = @oauth_authentication.id
    #     redirect_to new_user_registration_url
    #     return
    #   end
    # end
    @user = User.from_oauth_authentication(@oauth_authentication)

    @user.save!
    @oauth_authentication.save!

    sign_in_and_redirect @user, event: :authentication # this will throw if @user is not activated
    set_flash_message(:notice, :success, kind: @oauth_authentication.displayed_provider_name) if is_navigational_format?
  end

  def failure
    redirect_to root_path
  end
end
