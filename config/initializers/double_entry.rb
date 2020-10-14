# frozen_string_literal: true

Money.default_currency = Money::Currency.new(BentOS::Config.accounting.system_currency)
Money.rounding_mode = BigDecimal::ROUND_HALF_UP
Money.locale_backend = :i18n

require 'double_entry'

DoubleEntry.configure do |config|
  # Use json(b) column in double_entry_lines table to store metadata instead of separate metadata table
  config.json_metadata = true

  config.define_accounts do |accounts|
    user_scope = lambda do |user|
      raise 'not a User' unless user.class.name == 'User'

      user.id
    end

    group_order_group_scope = lambda do |group|
      raise 'not a GroupOrder::Group' unless group.class.name == 'GroupOrder::Group'

      group.id
    end

    # Representing the user's own money.
    # The balance should always be not more than zero, since users will only spend money in this system.
    accounts.define(scope_identifier: user_scope, identifier: :user_cash, negative_only: true)

    # The money in this account can be used to pay user's orders.
    # The balance may be a negative value if the user choise to pay after the order has been compeleted.
    accounts.define(scope_identifier: user_scope, identifier: :user_account)

    # Holded by the accounting manager, the money in this account repersents
    # how much money the accounting manager should give the group organizer.
    # The balance should be 0 when a group ends.
    accounts.define(scope_identifier: group_order_group_scope, identifier: :group_account)
  end

  config.define_transfers do |transfers|
    transfers.define(from: :user_cash, to: :user_account, code: :deposit)
    transfers.define(from: :user_account, to: :user_cash, code: :withdraw)

    transfers.define(from: :user_account, to: :group_account, code: :pay_group_order)

    transfers.define(from: :user_account, to: :user_account, code: :user_transfer)
  end
end
