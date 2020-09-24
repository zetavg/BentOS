# frozen_string_literal: true

class Accounting::UserWithdrawal < ActiveType::Object
  nests_one :user, scope: proc { User.all }
  attribute :amount, :decimal

  validates :user, presence: true
  validates :amount, numericality: { greater_than: 0 }, allow_blank: false
  validate :account_has_money
  validate :available_account_balance_sufficient

  before_save :transfer_money

  private

  def transfer_money
    from_account = DoubleEntry.account(:user_account, scope: user)
    to_account = DoubleEntry.account(:user_cash, scope: user)
    DoubleEntry.transfer(Money.from_amount(amount), code: :withdraw, from: from_account, to: to_account)
  end

  def account_has_money
    return if user.blank?
    return if user.available_account_balance.positive?

    errors.add(:user, :account_no_money, available_account_balance: user.available_account_balance.format)
  end

  def available_account_balance_sufficient
    return unless amount&.positive?
    return unless user&.available_account_balance&.positive?
    return if user.available_account_balance.to_d >= amount

    errors.add(
      :amount,
      :bigger_than_available_account_balance,
      available_account_balance: user.available_account_balance.format
    )
  end
end
