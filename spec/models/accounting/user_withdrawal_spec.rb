# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Accounting::UserWithdrawal, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_numericality_of(:amount).with_message('must be greater than 0').is_greater_than(0) }

    it 'is expected to validate that :user has money in account' do
      user_deposit = Accounting::UserWithdrawal.new

      user_with_account_balance = FactoryBot.create(:user, :confirmed, :with_account_balance, account_balance: 1)
      expect(user_deposit).to allow_value(user_with_account_balance).for(:user)

      user_with_account_balance_zero = FactoryBot.create(:user, :confirmed, :with_account_balance, account_balance: 0)
      expect(user_deposit).not_to(
        allow_value(user_with_account_balance_zero)
          .for(:user)
          .with_message("has no money in account (account balance is #{Money.from_amount(0).format})")
      )

      user_with_account_balance_neg = FactoryBot.create(:user, :confirmed, :with_account_balance, account_balance: -1)
      expect(user_deposit).not_to(
        allow_value(user_with_account_balance_neg)
          .for(:user)
          .with_message("has no money in account (account balance is #{Money.from_amount(-1).format})")
      )
    end

    it 'is expected to validate that :amount should not be larger then the balance of account' do
      account_balance = Money.from_amount(10_000)
      user = FactoryBot.create(:user, :confirmed, :with_account_balance, account_balance: account_balance)
      user_deposit = Accounting::UserWithdrawal.new(user: user)
      expect(user_deposit).to allow_value(1).for(:amount)
      expect(user_deposit).to allow_value(10_000).for(:amount)
      expect(user_deposit).not_to(
        allow_value(20_000)
          .for(:amount)
          .with_message("must be smaller than the account balance (#{account_balance.format})")
      )
      expect(user_deposit).not_to(
        allow_value(100_000)
          .for(:amount)
          .with_message("must be smaller than the account balance (#{account_balance.format})")
      )
    end
  end

  describe '#save' do
    let(:user) { FactoryBot.create(:user, :confirmed, :with_account_balance, account_balance: 10_000) }
    let(:user_deposit) { Accounting::UserWithdrawal.new(user: user, amount: 1000) }
    subject { user_deposit.save }

    it "withdrawals the amount of money from the user's account" do
      original_account_balance = user.account.balance

      expect { subject }.to change { user.account.balance }
        .from(original_account_balance)
        .to(original_account_balance - Money.from_amount(1000))
    end

    it "adds the amount of money to the user's cash" do
      cash_account = DoubleEntry.account(:user_cash, scope: user)
      original_account_balance = cash_account.balance

      expect { subject }.to change { cash_account.balance }
        .from(original_account_balance)
        .to(original_account_balance + Money.from_amount(1000))
    end

    context 'database failure during transaction' do
      before(:each) do
        # We need to force the user to be prepared before we set the database failure bomb,
        # otherwise it will explode during user and account preparation, not on the test subject.
        user

        last_sql_in_transaction_match = 'UPDATE "double_entry_lines"'
        DatabaseFailureSimulator.failure_on_next(last_sql_in_transaction_match)
      end
      after(:each) do
        DatabaseFailureSimulator.reset
      end

      it "raises error and does not change the user's account balance" do
        expect { subject }
          .to raise_error(DatabaseFailureSimulator::SimulatedDatabaseError)
          .and does_not_change { user.account.balance }
      end

      it "raises error and does not change the user's cash balance" do
        cash_account = DoubleEntry.account(:user_cash, scope: user)
        expect { subject }
          .to raise_error(DatabaseFailureSimulator::SimulatedDatabaseError)
          .and does_not_change { cash_account.balance }
      end
    end
  end
end
