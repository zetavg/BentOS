# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GroupOrder::OrderUpdate, type: :model do
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
  let(:order_placement) do
    GroupOrder::OrderPlacement.new(
      user: user,
      group: group,
      content: {
        items: [
          { uuid: 'i1', quantity: 1 },
          { uuid: 'i2', quantity: 1 }
        ]
      }
    )
  end
  let(:order) do
    order_placement.save!
    order_placement.order
  end
  let(:order_update) { GroupOrder::OrderUpdate.load(order) }

  describe 'validations' do
    it 'is expected to validate that the group is open' do
      expect(order_update).to be_valid

      group.state = :locked
      group._really_update = true # bypass the state immutable protect
      group.save!
      group._really_update = false
      expect(order_placement).not_to be_valid
      expect(order_placement.errors.details).to have_shape(
        { group: [{ error: :not_open, state: 'locked' }] }
      )
    end

    it 'is expected to validate that the order will be valid' do
      expect(order_update).to be_valid

      order_update.content = nil
      expect(order_update).to be_valid # update to :content will just be ignored

      order_update.content = {}
      expect(order_update).not_to be_valid
      expect(order_update.errors.details[:content]).to eq(order_update.order_to_update.errors.details[:content])

      order_update.content = {
        items: [
          { uuid: 'i999', quantity: 1 }
        ]
      }
      expect(order_update).not_to be_valid
      expect(order_update.errors.details[:content]).to eq(order_update.order_to_update.errors.details[:content])

      order_update.content = {
        items: [
          { uuid: 'i1', quantity: 1 },
          { uuid: 'i2', quantity: 1 }
        ]
      }

      expect(order_update).to be_valid
    end

    it 'is expected to validate that the user_authorization_hold will be valid' do
      order_update.content = {
        items: [
          { uuid: 'i1', quantity: 1 },
          { uuid: 'i2', quantity: 1 }
        ]
      }
      expect(order_update).to be_valid

      order_update.content = {
        items: [
          { uuid: 'i3', quantity: 1 }
        ]
      }
      expect(order_update).to be_valid

      order_update.content = {
        items: [
          { uuid: 'i3', quantity: 2 }
        ]
      }
      expect(order_update).not_to be_valid
      expect(order_update.errors.details[:base]).to eq(
        order_update.create_or_update_user_authorization_hold_to_submit.errors.details[:base]
      )
    end
  end

  describe '#save' do
    it 'updates the order' do
      order_update.content = {
        items: [
          { uuid: 'i1', quantity: 2 },
          { uuid: 'i2', quantity: 1 }
        ]
      }

      order_update.save!

      expect(order).to eq(order_update.order)
      expect(order_update.order).to eq(order_update.updated_order)
      expect(order_update.updated_order).to be_persisted
      expect(order_update.updated_order).not_to be_changed
      expect(order_update.updated_order.content).to have_shape(order_update.content)
      expect(order_update.updated_order.amount).to eq(Money.from_amount(400))
    end

    it 'updates the user_authorization_hold' do
      order_update.content = {
        items: [
          { uuid: 'i1', quantity: 2 },
          { uuid: 'i2', quantity: 1 }
        ]
      }

      order_update.save!

      expect(order_update.updated_order.authorization_hold).to be_persisted
      expect(order_update.updated_order.authorization_hold).not_to be_changed
      expect(order_update.updated_order.authorization_hold.amount).to eq(order_update.updated_order.amount)
      expect(order_update.updated_order.authorization_hold.transfer_code).to eq('pay_group_order')
      expect(order_update.updated_order.authorization_hold.partner_account).to eq(group.account)
      expect(order_update.updated_order.authorization_hold.detail).to eq(order_update.updated_order)
    end

    describe 'updated order' do
      let(:updated_order) do
        order_update.content = {
          items: [
            { uuid: 'i1', quantity: 2 },
            { uuid: 'i2', quantity: 1 }
          ]
        }
        order_update.save!
        order_update.order
      end

      it 'is still immutable' do
        expect(updated_order).to be_valid

        updated_order.content = {
          items: [{ uuid: 'i1', quantity: 1 }]
        }
        expect(updated_order).not_to be_valid
        expect(updated_order.errors.details).to have_shape({ base: [{ error: :immutable }] })
      end
    end
  end
end
