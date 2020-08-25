# frozen_string_literal: true

class Accounting::UserDeposit < ActiveType::Object
  nests_one :user, scope: proc { User.all }
  attribute :amount, :decimal

  validates :user, presence: true
  validates :amount, numericality: { greater_than: 0 }, allow_blank: false

  before_save :transfer_money

  private

  def transfer_money
    from_account = DoubleEntry.account(:user_cash, scope: user)
    to_account = DoubleEntry.account(:user_account, scope: user)
    DoubleEntry.transfer(Money.from_amount(amount), code: :deposit, from: from_account, to: to_account)
  end
end
