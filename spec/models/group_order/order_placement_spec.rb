# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GroupOrder::OrderPlacement, type: :model do
  let(:group) do
    FactoryBot.create(
      :group_order_group,
      menu: {
        menu: {
          sectionUuids: %w[s1]
        },
        sections: {
          s1: { name: 'Section 1', itemUuids: %w[i1 i2 i3] }
        },
        items: {
          i1: { name: 'Item 1', priceSubunits: 100_00 },
          i2: { name: 'Item 2', priceSubunits: 200_00 },
          i3: { name: 'Item 3', priceSubunits: 300_00 }
        }
      }
    )
  end
  let(:user) do
    FactoryBot.create(
      :user,
      :confirmed,
      :with_account_balance,
      account_balance: 500,
      credit_limit_subunit: 0
    )
  end
  let(:order_placement) { GroupOrder::OrderPlacement.new(user: user, group: group) }

  describe 'validations' do
    it 'is expected to validate that the group is open' do
      order_placement.content = {
        items: [
          { uuid: 'i1', quantity: 1 },
          { uuid: 'i2', quantity: 1 }
        ]
      }
      expect(order_placement).to be_valid

      group.state = :locked
      group.save!
      expect(order_placement).not_to be_valid
      expect(order_placement.errors.details).to have_shape(
        { group: [{ error: :not_open, state: 'locked' }] }
      )
    end

    it 'is expected to validate that the order will be valid' do
      order_placement.content = nil
      expect(order_placement).not_to be_valid
      expect(order_placement.errors.details[:content]).to eq(order_placement.order_to_create.errors.details[:content])

      order_placement.content = {}
      expect(order_placement).not_to be_valid
      expect(order_placement.errors.details[:content]).to eq(order_placement.order_to_create.errors.details[:content])

      order_placement.content = {
        items: [
          { uuid: 'i999', quantity: 1 }
        ]
      }
      expect(order_placement).not_to be_valid
      expect(order_placement.errors.details[:content]).to eq(order_placement.order_to_create.errors.details[:content])

      order_placement.content = {
        items: [
          { uuid: 'i1', quantity: 1 },
          { uuid: 'i2', quantity: 1 }
        ]
      }
      expect(order_placement).to be_valid
    end

    it 'is expected to validate that the user_authorization_hold will be valid' do
      order_placement.content = {
        items: [
          { uuid: 'i1', quantity: 1 },
          { uuid: 'i2', quantity: 1 }
        ]
      }
      expect(order_placement).to be_valid

      order_placement.content = {
        items: [
          { uuid: 'i3', quantity: 1 }
        ]
      }
      expect(order_placement).to be_valid

      order_placement.content = {
        items: [
          { uuid: 'i3', quantity: 2 }
        ]
      }
      expect(order_placement).not_to be_valid
      expect(order_placement.errors.details[:base]).to eq(
        order_placement.create_or_update_user_authorization_hold_to_submit.errors.details[:base]
      )
    end
  end

  describe '#save' do
    it 'creates the order' do
      order_placement.content = {
        items: [
          { uuid: 'i1', quantity: 1 },
          { uuid: 'i2', quantity: 1 }
        ]
      }

      order_placement.save!

      expect(order_placement.order).to be_persisted
      expect(order_placement.order).not_to be_changed
      expect(order_placement.order.user).to eq(order_placement.user)
      expect(order_placement.order.group).to eq(order_placement.group)
      expect(order_placement.order.content).to have_shape(order_placement.content)
      expect(order_placement.order.amount).to eq(Money.from_amount(300))
    end

    it 'creates the user_authorization_hold' do
      order_placement.content = {
        items: [
          { uuid: 'i1', quantity: 1 },
          { uuid: 'i2', quantity: 1 }
        ]
      }

      order_placement.save!

      expect(order_placement.order.authorization_hold).to be_persisted
      expect(order_placement.order.authorization_hold).not_to be_changed
      expect(order_placement.order.authorization_hold.user).to eq(order_placement.user)
      expect(order_placement.order.authorization_hold.amount).to eq(order_placement.order.amount)
      expect(order_placement.order.authorization_hold.transfer_code).to eq('pay_group_order')
      expect(order_placement.order.authorization_hold.partner_account).to eq(group.account)
      expect(order_placement.order.authorization_hold.detail).to eq(order_placement.order)
    end

    describe 'created order' do
      let(:created_order) do
        order_placement.content = {
          items: [
            { uuid: 'i1', quantity: 1 },
            { uuid: 'i2', quantity: 1 }
          ]
        }
        order_placement.save!
        order_placement.order
      end

      it 'is immutable' do
        expect(created_order).to be_valid

        created_order.content = {
          items: [{ uuid: 'i1', quantity: 1 }]
        }
        expect(created_order).not_to be_valid
        expect(created_order.errors.details).to have_shape({ base: [{ error: :immutable }] })
      end
    end
  end
end
