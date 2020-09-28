# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GroupOrder::Group, type: :model do
  describe 'relations' do
    it { is_expected.to belong_to(:organizer) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:to_be_closed_at) }
    it { is_expected.to validate_presence_of(:expected_delivery_time) }
    it { is_expected.to validate_numericality_of(:group_minimum_amount).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:group_minimum_sets).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:group_maximum_amount).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:group_maximum_sets).is_greater_than(0) }

    it 'is expected to validate that :menu is in line with the JSON Schema' do
      group = FactoryBot.build(:group_order_group)
      expect(group).to be_valid

      group.menu = nil
      expect(group).not_to be_valid
      expect(group.errors.details).to have_shape(
        {
          menu: [
            { error: "The property '#/' of type null did not match the following type: object in schema" }
          ]
        }
      )

      group.menu = {}
      expect(group).not_to be_valid
      expect(group.errors.details).to have_shape(
        {
          menu: [
            { error: "The property '#/' did not contain a required property of 'menu' in schema" },
            { error: "The property '#/' did not contain a required property of 'sections' in schema" },
            { error: "The property '#/' did not contain a required property of 'items' in schema" }
          ]
        }
      )

      # Maybe we can test more...
    end

    it 'is expected to validate that all menu.sectionUuids exists under the sections object in :menu' do
      group = FactoryBot.build(:group_order_group)
      group.menu = {
        menu: {
          sectionUuids: ['a', 'b', 'c']
        },
        sections: {
          a: { name: 'A', itemUuids: [] },
          b: { name: 'B', itemUuids: [] },
          c: { name: 'C', itemUuids: [] }
        },
        items: {}
      }
      expect(group).to be_valid

      group.menu = {
        menu: {
          sectionUuids: ['a', 'b', 'c']
        },
        sections: {
          a: { name: 'A', itemUuids: [] },
          c: { name: 'C', itemUuids: [] }
        },
        items: {}
      }
      expect(group).not_to be_valid
      expect(group.errors.details).to have_shape(
        {
          menu: [
            { error: :sections_missing, missing_section_uuids: ['b'] }
          ]
        }
      )
    end

    it 'is expected to validate that all menu.sections[id].itemUuids exists under the items object in :menu' do
      group = FactoryBot.build(:group_order_group)
      group.menu = {
        menu: {
          sectionUuids: ['foo', 'bar']
        },
        sections: {
          foo: { name: 'A', itemUuids: ['a', 'b'] },
          bar: { name: 'A', itemUuids: ['b', 'c'] }
        },
        items: {
          a: { name: 'A', priceSubunits: 0 },
          b: { name: 'B', priceSubunits: 0 },
          c: { name: 'C', priceSubunits: 0 }
        }
      }
      expect(group).to be_valid

      group.menu = {
        menu: {
          sectionUuids: ['foo', 'bar']
        },
        sections: {
          foo: { name: 'A', itemUuids: ['a', 'b'] },
          bar: { name: 'A', itemUuids: ['b', 'c'] }
        },
        items: {
          a: { name: 'A', priceSubunits: 0 },
          b: { name: 'B', priceSubunits: 0 }
        }
      }
      expect(group).not_to be_valid
      expect(group.errors.details).to have_shape(
        {
          menu: [
            { error: :items_missing, missing_item_uuids: ['c'] }
          ]
        }
      )
    end

    it 'is expected to validate that all menu.items[id].customizationUuids exists under the customizations object in :menu' do
      group = FactoryBot.build(:group_order_group)
      group.menu = {
        menu: {
          sectionUuids: ['sec']
        },
        sections: {
          sec: { name: 'Section', itemUuids: ['foo', 'bar'] }
        },
        items: {
          foo: { name: 'Foo', priceSubunits: 0, customizationUuids: ['a', 'b'] },
          bar: { name: 'Bar', priceSubunits: 0, customizationUuids: ['a', 'c'] }
        },
        customizations: {
          a: { name: 'A', optionUuids: [] },
          b: { name: 'B', optionUuids: [] },
          c: { name: 'C', optionUuids: [] }
        }
      }
      expect(group).to be_valid

      group.menu = {
        menu: {
          sectionUuids: ['sec']
        },
        sections: {
          sec: { name: 'Section', itemUuids: ['foo', 'bar'] }
        },
        items: {
          foo: { name: 'Foo', priceSubunits: 0, customizationUuids: ['a', 'b'] },
          bar: { name: 'Bar', priceSubunits: 0, customizationUuids: ['a', 'c'] }
        },
        customizations: {
          a: { name: 'A', optionUuids: [] },
          b: { name: 'B', optionUuids: [] }
        }
      }
      expect(group).not_to be_valid
      expect(group.errors.details).to have_shape(
        {
          menu: [
            { error: :customizations_missing, missing_customization_uuids: ['c'] }
          ]
        }
      )

      group.menu = {
        menu: {
          sectionUuids: ['sec']
        },
        sections: {
          sec: { name: 'Section', itemUuids: ['foo', 'bar'] }
        },
        items: {
          foo: { name: 'Foo', priceSubunits: 0, customizationUuids: ['a', 'b'] },
          bar: { name: 'Bar', priceSubunits: 0, customizationUuids: ['a', 'c'] }
        }
      }
      expect(group).not_to be_valid
      expect(group.errors.details).to have_shape(
        {
          menu: [
            { error: :customizations_missing, missing_customization_uuids: ['a', 'b', 'c'] }
          ]
        }
      )
    end

    it 'is expected to validate that all menu.customizations[id].optionUuids exists under the customizationOptions object in :menu' do
      group = FactoryBot.build(:group_order_group)
      group.menu = {
        menu: {
          sectionUuids: ['sec']
        },
        sections: {
          sec: { name: 'Section', itemUuids: ['ite'] }
        },
        items: {
          ite: { name: 'Item', priceSubunits: 0, customizationUuids: ['foo', 'bar'] }
        },
        customizations: {
          foo: { name: 'Customization', optionUuids: ['a', 'b'] },
          bar: { name: 'Customization', optionUuids: ['a', 'c'] }
        },
        customizationOptions: {
          a: { name: 'A' },
          b: { name: 'B' },
          c: { name: 'C' }
        }
      }
      expect(group).to be_valid

      group.menu = {
        menu: {
          sectionUuids: ['sec']
        },
        sections: {
          sec: { name: 'Section', itemUuids: ['ite'] }
        },
        items: {
          ite: { name: 'Item', priceSubunits: 0, customizationUuids: ['foo', 'bar'] }
        },
        customizations: {
          foo: { name: 'Customization', optionUuids: ['a', 'b'] },
          bar: { name: 'Customization', optionUuids: ['a', 'c'] }
        },
        customizationOptions: {
          a: { name: 'A' },
          b: { name: 'B' }
        }
      }
      expect(group).not_to be_valid
      expect(group.errors.details).to have_shape(
        {
          menu: [
            { error: :customization_options_missing, missing_customization_option_uuids: ['c'] }
          ]
        }
      )
    end
  end
end
