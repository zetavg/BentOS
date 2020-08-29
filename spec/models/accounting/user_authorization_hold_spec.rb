# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Accounting::UserAuthorizationHold, type: :model do
  let(:user) { FactoryBot.create(:user, :confirmed, :with_account_balance, account_balance: 1000) }
  let(:partner_user) { FactoryBot.create(:user, :confirmed) }
  let(:user_authorization_hold) do
    Accounting::UserAuthorizationHold.create(
      user: user,
      amount: 100,
      transfer_code: :user_transfer,
      partner_account: partner_user.account
    )
  end

  describe 'virtual attributes' do
    describe '#partner_account' do
      it 'returns the partner_account correctly' do
        user_authorization_hold.partner_account_identifier = 'user_account'
        user_authorization_hold.partner_account_scope_identity = 'scope-identity'

        expect(user_authorization_hold.partner_account).to be_a(DoubleEntry::Account::Instance)
        expect(user_authorization_hold.partner_account.identifier).to be(:user_account)
        expect(user_authorization_hold.partner_account.scope_identity).to eq('scope-identity')
      end

      it 'returns nil if partner_account_identifier is invalid' do
        user_authorization_hold.partner_account_identifier = 'no_such_account'
        user_authorization_hold.partner_account_scope_identity = 'scope-identity'

        expect(user_authorization_hold.partner_account).to be(nil)

        user_authorization_hold.partner_account_identifier = nil
        user_authorization_hold.partner_account_scope_identity = nil

        expect(user_authorization_hold.partner_account).to be(nil)
      end

      it 'returns nil if partner_account_scope_identity is invalid' do
        user_authorization_hold.partner_account_identifier = 'user_account'
        user_authorization_hold.partner_account_scope_identity = nil # invalid for scoped account: :user_account

        expect(user_authorization_hold.partner_account).to be(nil)
      end
    end

    describe '#partner_account=' do
      it 'assigns partner_account_identifier and partner_account_scope_identity correctly' do
        user_authorization_hold.partner_account = user.account

        expect(user_authorization_hold.partner_account_identifier).to eq('user_account')
        expect(user_authorization_hold.partner_account_scope_identity).to eq(user.id)
      end

      it 'assigns partner_account_identifier and partner_account_scope_identity to nil if given unknown stuff' do
        user_authorization_hold.partner_account = 'lkdii38of8u'

        expect(user_authorization_hold.partner_account_identifier).to be(nil)
        expect(user_authorization_hold.partner_account_scope_identity).to be(nil)

        user_authorization_hold.partner_account = nil

        expect(user_authorization_hold.partner_account_identifier).to be(nil)
        expect(user_authorization_hold.partner_account_scope_identity).to be(nil)

        user_authorization_hold.partner_account = 2874

        expect(user_authorization_hold.partner_account_identifier).to be(nil)
        expect(user_authorization_hold.partner_account_scope_identity).to be(nil)

        user_authorization_hold.partner_account = user

        expect(user_authorization_hold.partner_account_identifier).to be(nil)
        expect(user_authorization_hold.partner_account_scope_identity).to be(nil)
      end
    end
  end

  describe 'relations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it { is_expected.to validate_numericality_of(:amount).with_message('must be greater than 0').is_greater_than(0) }

    it 'is expected to validate that :transfer_code is valid in double_entry' do
      expect(user_authorization_hold).to allow_value(:user_transfer).for(:transfer_code)
      expect(user_authorization_hold).not_to allow_value(:user_translate).for(:transfer_code)
      expect(user_authorization_hold).not_to allow_value(nil).for(:transfer_code)
      expect(user_authorization_hold).not_to allow_value(false).for(:transfer_code)
      expect(user_authorization_hold).not_to allow_value(123).for(:transfer_code)
    end

    it 'is expected to validate that :partner_account is valid for :transfer_code in double_entry' do
      # TODO: Replace these examples with ones that make sence after we have more avaliable business logic

      user_authorization_hold.transfer_code = :user_transfer
      expect(user_authorization_hold).to(
        allow_value(DoubleEntry.account(:user_account, scope: user)).for(:partner_account)
      )
      expect(user_authorization_hold).not_to(
        allow_value(DoubleEntry.account(:user_cash, scope: user)).for(:partner_account)
      )

      user_authorization_hold.transfer_code = :withdraw
      expect(user_authorization_hold).not_to(
        allow_value(DoubleEntry.account(:user_account, scope: user)).for(:partner_account)
      )
      expect(user_authorization_hold).to(
        allow_value(DoubleEntry.account(:user_cash, scope: user)).for(:partner_account)
      )
    end
  end

  describe 'lifecycle' do
    describe 'states' do
    end

    describe 'events' do
      describe '#capture!' do
        it 'changes the state from holding to closed' do
          expect { user_authorization_hold.capture! }.to(
            change { user_authorization_hold.state }.from('holding').to('closed')
          )
        end

        it 'transfers the money to the :partner_account' do
          original_account_balance = user.account.balance
          original_partner_account_balance = partner_user.account.balance

          expect { user_authorization_hold.capture! }
            .to change { user.account.balance }
            .from(original_account_balance)
            .to(original_account_balance - user_authorization_hold.amount)
            .and change { partner_user.account.balance }
            .from(original_partner_account_balance)
            .to(original_partner_account_balance + user_authorization_hold.amount)
        end

        it "stores it's id in capture transfer line metadatas" do
          expect { user_authorization_hold.capture! }
            .to change {
              DoubleEntry::Line.find_by(
                "metadata ->> 'authorization_hold_id' = ? AND scope = ?",
                user_authorization_hold.id,
                user.id
              )&.metadata&.fetch('authorization_hold_id', nil)
            }
            .from(nil)
            .to(user_authorization_hold.id)
            .and change {
              DoubleEntry::Line.find_by(
                "metadata ->> 'authorization_hold_id' = ? AND scope = ?",
                user_authorization_hold.id,
                partner_user.id
              )&.metadata&.fetch('authorization_hold_id', nil)
            }
            .from(nil)
            .to(user_authorization_hold.id)
        end

        context 'has metadata as JSON object' do
          let(:user_authorization_hold) do
            Accounting::UserAuthorizationHold.create(
              user: user,
              amount: 100,
              transfer_code: :user_transfer,
              partner_account: partner_user.account,
              metadata: {
                foo: 'bar'
              }
            )
          end

          it "stores it's id in capture transfer line metadatas" do
            expect { user_authorization_hold.capture! }
              .to change {
                DoubleEntry::Line.find_by(
                  "metadata ->> 'authorization_hold_id' = ? AND scope = ?",
                  user_authorization_hold.id,
                  user.id
                )&.metadata&.fetch('authorization_hold_id', nil)
              }
              .from(nil)
              .to(user_authorization_hold.id)
              .and change {
                DoubleEntry::Line.find_by(
                  "metadata ->> 'authorization_hold_id' = ? AND scope = ?",
                  user_authorization_hold.id,
                  partner_user.id
                )&.metadata&.fetch('authorization_hold_id', nil)
              }
              .from(nil)
              .to(user_authorization_hold.id)
          end

          it "stores it's metadata in capture transfer line metadatas" do
            expect { user_authorization_hold.capture! }
              .to change {
                DoubleEntry::Line.find_by(
                  "metadata ->> 'authorization_hold_id' = ? AND scope = ?",
                  user_authorization_hold.id,
                  user.id
                )&.metadata&.fetch('foo', nil)
              }
              .from(nil)
              .to('bar')
              .and change {
                DoubleEntry::Line.find_by(
                  "metadata ->> 'authorization_hold_id' = ? AND scope = ?",
                  user_authorization_hold.id,
                  partner_user.id
                )&.metadata&.fetch('foo', nil)
              }
              .from(nil)
              .to('bar')
          end
        end

        context 'has metadata as scalar value' do
          let(:user_authorization_hold) do
            Accounting::UserAuthorizationHold.create(
              user: user,
              amount: 100,
              transfer_code: :user_transfer,
              partner_account: partner_user.account,
              metadata: 'foo'
            )
          end

          it "stores it's id in capture transfer line metadatas" do
            expect { user_authorization_hold.capture! }
              .to change {
                DoubleEntry::Line.find_by(
                  "metadata ->> 'authorization_hold_id' = ? AND scope = ?",
                  user_authorization_hold.id,
                  user.id
                )&.metadata&.fetch('authorization_hold_id', nil)
              }
              .from(nil)
              .to(user_authorization_hold.id)
              .and change {
                DoubleEntry::Line.find_by(
                  "metadata ->> 'authorization_hold_id' = ? AND scope = ?",
                  user_authorization_hold.id,
                  partner_user.id
                )&.metadata&.fetch('authorization_hold_id', nil)
              }
              .from(nil)
              .to(user_authorization_hold.id)
          end

          it "stores it's metadata in capture transfer line metadatas' value field" do
            expect { user_authorization_hold.capture! }
              .to change {
                DoubleEntry::Line.find_by(
                  "metadata ->> 'authorization_hold_id' = ? AND scope = ?",
                  user_authorization_hold.id,
                  user.id
                )&.metadata&.fetch('value', nil)
              }
              .from(nil)
              .to('foo')
              .and change {
                DoubleEntry::Line.find_by(
                  "metadata ->> 'authorization_hold_id' = ? AND scope = ?",
                  user_authorization_hold.id,
                  partner_user.id
                )&.metadata&.fetch('value', nil)
              }
              .from(nil)
              .to('foo')
          end
        end

        context 'has detail' do
          let(:user_authorization_hold) do
            Accounting::UserAuthorizationHold.create(
              user: user,
              amount: 100,
              transfer_code: :user_transfer,
              partner_account: partner_user.account,
              detail: partner_user
            )
          end

          it "stores it's detail in capture transfer line detail" do
            expect { user_authorization_hold.capture! }
              .to change {
                DoubleEntry::Line.find_by(
                  "metadata ->> 'authorization_hold_id' = ? AND scope = ?",
                  user_authorization_hold.id,
                  user.id
                )&.detail&.id
              }
              .from(nil)
              .to(partner_user.id)
              .and change {
                DoubleEntry::Line.find_by(
                  "metadata ->> 'authorization_hold_id' = ? AND scope = ?",
                  user_authorization_hold.id,
                  partner_user.id
                )&.detail&.id
              }
              .from(nil)
              .to(partner_user.id)
          end
        end
      end

      describe '#reverse!' do
        it 'changes the state from holding to reversed' do
          expect { user_authorization_hold.reverse! }.to(
            change { user_authorization_hold.state }.from('holding').to('reversed')
          )
        end
      end
    end
  end
end
