# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Accounting::UserDeposit, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_numericality_of(:amount).with_message('must be greater than 0').is_greater_than(0) }
  end

  describe '#save' do
    let(:user) { FactoryBot.create(:user, :confirmed) }
    let(:user_deposit) { Accounting::UserDeposit.new(user: user, amount: 1000) }
    subject { user_deposit.save }

    it "deposits the amount of money into the user's account" do
      original_account_balance = user.account.balance

      expect { subject }.to change { user.account.balance }
        .from(original_account_balance)
        .to(original_account_balance + Money.from_amount(1000))
    end

    it "deducts the amount of money from the user's cash" do
      cash_account = DoubleEntry.account(:user_cash, scope: user)
      original_account_balance = cash_account.balance

      expect { subject }.to change { cash_account.balance }
        .from(original_account_balance)
        .to(original_account_balance - Money.from_amount(1000))
    end

    context 'database failure during transaction' do
      before(:each) do
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
