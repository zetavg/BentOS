# frozen_string_literal: true

class User < ApplicationRecord
  devise :database_authenticatable, :rememberable, :recoverable, :lockable,
         :registerable, :omniauthable, :validatable, :confirmable

  monetize :credit_limit_subunit, as: :credit_limit, allow_nil: true

  has_many :oauth_authentications, dependent: :destroy
  has_many :authorization_holds, class_name: 'Accounting::UserAuthorizationHold', dependent: :destroy

  validates :credit_limit, numericality: { greater_than: 0 }

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

  def account
    DoubleEntry.account(:user_account, scope: self)
  end

  def account_transactions
    DoubleEntry::Line.where(account: :user_account, scope: id)
  end

  def credit_limit
    return Money.new(credit_limit_subunit) if credit_limit_subunit.present?

    Money.from_amount(BentOS::Config.accounting.default_credit_limit_amount)
  end

  def remaining_credit_limit
    credit_limit + account_balance - authorization_hold_amount
  end

  delegate :balance, to: :account, prefix: true

  def available_account_balance
    account_balance - authorization_hold_amount
  end

  def authorization_hold_amount
    authorization_holds.holding.map(&:amount).sum
  end

  protected

  def password_required?
    false
  end
end
