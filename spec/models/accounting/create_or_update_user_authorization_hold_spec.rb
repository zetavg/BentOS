# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Accounting::CreateOrUpdateUserAuthorizationHold, type: :model do
  let(:user) do
    FactoryBot.create(
      :user,
      :confirmed,
      :with_account_balance,
      account_balance: 1000,
      credit_limit: 500
    )
  end
  let(:partner_user) { FactoryBot.create(:user, :confirmed) }
  let(:create_or_update_user_authorization_hold) do
    Accounting::CreateOrUpdateUserAuthorizationHold.new(
      uuid: SecureRandom.uuid,
      user: user,
      amount: 100,
      transfer_code: :user_transfer,
      partner_account: partner_user.account
    )
  end

  # TODO: Consider making these test cases shared examples since there're
  # same as Accounting::UserAuthorizationHold spec
  describe 'validations' do
    it { is_expected.to validate_numericality_of(:amount).with_message('must be greater than 0').is_greater_than(0) }

    it 'is expected to validate that :uuid is a valid UUID' do
      expect(create_or_update_user_authorization_hold).to allow_value('c8947d54-daa7-40b1-ad91-205b561a2a91').for(:uuid)
      expect(create_or_update_user_authorization_hold).to allow_value('a8aa5ead-da23-42b6-89dc-d69dd6409264').for(:uuid)
      expect(create_or_update_user_authorization_hold).to allow_value(SecureRandom.uuid).for(:uuid)

      expect(create_or_update_user_authorization_hold).not_to allow_value('a8aa5ead-da23-42b6-89dc').for(:uuid)
      expect(create_or_update_user_authorization_hold).not_to allow_value('').for(:uuid)
      expect(create_or_update_user_authorization_hold).not_to allow_value('-').for(:uuid)
    end

    it "is expected to validate that :uuid doesn't belongs to a UserAuthorizationHold that is :closed or :reversed" do
      holding_user_authorization_hold = Accounting::UserAuthorizationHold.create(
        user: user,
        amount: 100,
        transfer_code: :user_transfer,
        partner_account: partner_user.account
      )
      closed_user_authorization_hold = Accounting::UserAuthorizationHold.create(
        user: user,
        amount: 100,
        transfer_code: :user_transfer,
        partner_account: partner_user.account,
        state: :closed
      )
      reversed_user_authorization_hold = Accounting::UserAuthorizationHold.create(
        user: user,
        amount: 100,
        transfer_code: :user_transfer,
        partner_account: partner_user.account,
        state: :reversed
      )
      expect(create_or_update_user_authorization_hold).to allow_value(holding_user_authorization_hold.id).for(:uuid)
      expect(create_or_update_user_authorization_hold).not_to allow_value(closed_user_authorization_hold.id).for(:uuid)
      expect(create_or_update_user_authorization_hold).not_to(
        allow_value(reversed_user_authorization_hold.id).for(:uuid)
      )
    end

    it 'is expected to validate that :transfer_code is valid in double_entry' do
      expect(create_or_update_user_authorization_hold).to allow_value(:user_transfer).for(:transfer_code)
      expect(create_or_update_user_authorization_hold).not_to allow_value(:user_translate).for(:transfer_code)
      expect(create_or_update_user_authorization_hold).not_to allow_value(nil).for(:transfer_code)
      expect(create_or_update_user_authorization_hold).not_to allow_value(false).for(:transfer_code)
      expect(create_or_update_user_authorization_hold).not_to allow_value(123).for(:transfer_code)
    end

    it 'is expected to validate that :partner_account is valid for :transfer_code in double_entry' do
      # TODO: Replace these examples with ones that make sence after we have more avaliable business logic

      create_or_update_user_authorization_hold.transfer_code = :user_transfer
      expect(create_or_update_user_authorization_hold).to(
        allow_value(DoubleEntry.account(:user_account, scope: user)).for(:partner_account)
      )
      expect(create_or_update_user_authorization_hold).not_to(
        allow_value(DoubleEntry.account(:user_cash, scope: user)).for(:partner_account)
      )

      create_or_update_user_authorization_hold.transfer_code = :withdraw
      expect(create_or_update_user_authorization_hold).not_to(
        allow_value(DoubleEntry.account(:user_account, scope: user)).for(:partner_account)
      )
      expect(create_or_update_user_authorization_hold).to(
        allow_value(DoubleEntry.account(:user_cash, scope: user)).for(:partner_account)
      )
    end

    it 'is expected to validate that the user have enough remaining credit limit' do
      expect(user.remaining_credit_limit).to eq(Money.from_amount(1500))

      create_or_update_user_authorization_hold.amount = Money.from_amount(500)
      expect(create_or_update_user_authorization_hold).to be_valid

      create_or_update_user_authorization_hold.amount = Money.from_amount(1500)
      expect(create_or_update_user_authorization_hold).to be_valid

      create_or_update_user_authorization_hold.amount = Money.from_amount(1501)
      expect(create_or_update_user_authorization_hold).not_to be_valid
      expect(create_or_update_user_authorization_hold.errors.details[:base]).to have_shape(
        [
          {
            error: :user_remaining_credit_limit_insufficient,
            user_remaining_credit_limit: Money.from_amount(1500),
            amount: Money.from_amount(1501)
          }
        ]
      )
    end
  end

  describe '#save' do
    # TODO: Replace these examples with ones that make sence after we have more avaliable business logic
    context 'with existing user_authorization_hold' do
      let(:user_authorization_hold) do
        Accounting::UserAuthorizationHold.create(
          user: user,
          amount: 100,
          transfer_code: :user_transfer,
          partner_account: partner_user.account
        )
      end
      let(:create_or_update_user_authorization_hold) do
        Accounting::CreateOrUpdateUserAuthorizationHold.new(
          uuid: user_authorization_hold.id
        )
      end

      it 'updates the amount of the existing user_authorization_hold' do
        create_or_update_user_authorization_hold.amount = 200
        expect { create_or_update_user_authorization_hold.save! }.to(
          change { user_authorization_hold.reload.amount }
            .from(Money.from_amount(100))
            .to(Money.from_amount(200))
          .and(does_not_change { user_authorization_hold.reload.user })
          .and(does_not_change { user_authorization_hold.reload.transfer_code })
          .and(does_not_change { user_authorization_hold.reload.partner_account })
          .and(does_not_change { user_authorization_hold.reload.detail })
          .and(does_not_change { user_authorization_hold.reload.metadata })
        )
      end

      it 'updates the user of the existing user_authorization_hold' do
        new_user = FactoryBot.create(:user, :confirmed)
        create_or_update_user_authorization_hold.user = new_user
        expect { create_or_update_user_authorization_hold.save! }.to(
          change { user_authorization_hold.reload.user }
            .from(user)
            .to(new_user)
          .and(does_not_change { user_authorization_hold.reload.amount })
          .and(does_not_change { user_authorization_hold.reload.transfer_code })
          .and(does_not_change { user_authorization_hold.reload.partner_account })
          .and(does_not_change { user_authorization_hold.reload.detail })
          .and(does_not_change { user_authorization_hold.reload.metadata })
        )
      end

      it 'updates the partner_account of the existing user_authorization_hold' do
        new_user = FactoryBot.create(:user, :confirmed)
        create_or_update_user_authorization_hold.partner_account = new_user.account
        expect { create_or_update_user_authorization_hold.save! }.to(
          change { user_authorization_hold.reload.partner_account }
            .from(partner_user.account)
            .to(new_user.account)
          .and(does_not_change { user_authorization_hold.reload.user })
          .and(does_not_change { user_authorization_hold.reload.amount })
          .and(does_not_change { user_authorization_hold.reload.transfer_code })
          .and(does_not_change { user_authorization_hold.reload.detail })
          .and(does_not_change { user_authorization_hold.reload.metadata })
        )
      end

      it 'updates the transfer_code of the existing user_authorization_hold' do
        create_or_update_user_authorization_hold.partner_account = DoubleEntry.account(:user_cash, scope: user)
        create_or_update_user_authorization_hold.transfer_code = :withdraw
        expect { create_or_update_user_authorization_hold.save! }.to(
          change { user_authorization_hold.reload.transfer_code }
            .from('user_transfer')
            .to('withdraw')
          .and(does_not_change { user_authorization_hold.reload.user })
          .and(does_not_change { user_authorization_hold.reload.amount })
          .and(does_not_change { user_authorization_hold.reload.detail })
          .and(does_not_change { user_authorization_hold.reload.metadata })
        )
      end

      it 'updates the metadata of the existing user_authorization_hold' do
        create_or_update_user_authorization_hold.metadata = { 'foo' => 'bar' }
        expect { create_or_update_user_authorization_hold.save! }.to(
          change { user_authorization_hold.reload.metadata }
            .from(nil)
            .to({ 'foo' => 'bar' })
          .and(does_not_change { user_authorization_hold.reload.user })
          .and(does_not_change { user_authorization_hold.reload.amount })
          .and(does_not_change { user_authorization_hold.reload.transfer_code })
          .and(does_not_change { user_authorization_hold.reload.partner_account })
          .and(does_not_change { user_authorization_hold.reload.detail })
        )

        create_or_update_user_authorization_hold.metadata = { 'foo' => 1, 'bar' => { 'baz' => 2 } }
        expect { create_or_update_user_authorization_hold.save! }.to(
          change { user_authorization_hold.reload.metadata }
            .from({ 'foo' => 'bar' })
            .to({ 'foo' => 1, 'bar' => { 'baz' => 2 } })
          .and(does_not_change { user_authorization_hold.reload.user })
          .and(does_not_change { user_authorization_hold.reload.amount })
          .and(does_not_change { user_authorization_hold.reload.transfer_code })
          .and(does_not_change { user_authorization_hold.reload.partner_account })
          .and(does_not_change { user_authorization_hold.reload.detail })
        )
      end

      it 'updates the detail of the existing user_authorization_hold' do
        create_or_update_user_authorization_hold.detail = user
        expect { create_or_update_user_authorization_hold.save! }.to(
          change { user_authorization_hold.reload.detail }
            .from(nil)
            .to(user)
          .and(does_not_change { user_authorization_hold.reload.user })
          .and(does_not_change { user_authorization_hold.reload.amount })
          .and(does_not_change { user_authorization_hold.reload.transfer_code })
          .and(does_not_change { user_authorization_hold.reload.partner_account })
          .and(does_not_change { user_authorization_hold.reload.metadata })
        )

        create_or_update_user_authorization_hold.detail = partner_user
        expect { create_or_update_user_authorization_hold.save! }.to(
          change { user_authorization_hold.reload.detail }
            .from(user)
            .to(partner_user)
          .and(does_not_change { user_authorization_hold.reload.user })
          .and(does_not_change { user_authorization_hold.reload.amount })
          .and(does_not_change { user_authorization_hold.reload.transfer_code })
          .and(does_not_change { user_authorization_hold.reload.partner_account })
          .and(does_not_change { user_authorization_hold.reload.metadata })
        )
      end
    end

    context 'without existing user_authorization_hold' do
      let(:create_or_update_user_authorization_hold) do
        Accounting::CreateOrUpdateUserAuthorizationHold.new(
          uuid: SecureRandom.uuid,
          user: user,
          amount: 100,
          transfer_code: :user_transfer,
          partner_account: partner_user.account,
          detail: partner_user,
          metadata: { 'foo' => 'bar' }
        )
      end

      it 'creates the user_authorization_hold' do
        expect(Accounting::UserAuthorizationHold.find_by(id: create_or_update_user_authorization_hold.uuid)).to be(nil)

        create_or_update_user_authorization_hold.save!

        created_user_authorization_hold = Accounting::UserAuthorizationHold.find(
          create_or_update_user_authorization_hold.uuid
        )
        expect(created_user_authorization_hold)
          .to have_shape(
            {
              id: create_or_update_user_authorization_hold.uuid,
              state: 'holding',
              transfer_code: create_or_update_user_authorization_hold.transfer_code,
              metadata: create_or_update_user_authorization_hold.metadata
            }
          )
        expect(created_user_authorization_hold.user).to eq(create_or_update_user_authorization_hold.user)
        expect(created_user_authorization_hold.amount).to(
          eq(Money.from_amount(create_or_update_user_authorization_hold.amount))
        )
        expect(created_user_authorization_hold.partner_account).to(
          eq(create_or_update_user_authorization_hold.partner_account)
        )
        expect(created_user_authorization_hold.detail).to eq(create_or_update_user_authorization_hold.detail)
      end
    end
  end
end
