# frozen_string_literal: true

class Accounting::UserWithdrawal < ActiveType::Object
  nests_one :user, scope: proc { User.all }
  attribute :amount, :decimal

  validates :user, presence: true
  validates :amount, numericality: { greater_than: 0 }, allow_blank: false
  validate :account_has_money
  validate :account_balance_sufficient

  before_save :transfer_money

  private

  def transfer_money
    from_account = DoubleEntry.account(:user_account, scope: user)
    to_account = DoubleEntry.account(:user_cash, scope: user)
    DoubleEntry.transfer(Money.from_amount(amount), code: :withdraw, from: from_account, to: to_account)
  end

  def account_has_money
    return if user.blank?
    return if user.account.balance.positive?

    errors.add(:user, :account_no_money, account_balance: user.account.balance.format)
  end

  def account_balance_sufficient
    return unless amount&.positive?
    return unless user&.account&.balance&.positive?
    return if user.account.balance.to_d >= amount

    errors.add(:amount, :bigger_than_account_balance, account_balance: user.account.balance.format)
  end
end
