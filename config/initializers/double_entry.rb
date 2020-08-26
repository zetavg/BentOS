# frozen_string_literal: true

Money.default_currency = Money::Currency.new(BentOS::Config.accounting.system_currency)

require 'double_entry'

DoubleEntry.configure do |config|
  # Use json(b) column in double_entry_lines table to store metadata instead of separate metadata table
  config.json_metadata = true

  config.define_accounts do |accounts|
    user_scope = lambda do |user|
      raise 'not a User' unless user.class.name == 'User'

      user.id
    end

    # Representing the user's own money.
    # The balance should always be not more than zero, since users will only spend money in this system.
    accounts.define(scope_identifier: user_scope, identifier: :user_cash, negative_only: true)
    # The money in this account can be used to pay user's orders.
    # The balance may be a negative value if the user choise to pay after the order has been compeleted.
    accounts.define(scope_identifier: user_scope, identifier: :user_account)
  end

  config.define_transfers do |transfers|
    transfers.define(from: :user_cash, to: :user_account, code: :deposit)
    transfers.define(from: :user_account, to: :user_cash, code: :withdraw)
  end
end
