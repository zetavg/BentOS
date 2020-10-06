# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Layout/LineLength
RSpec.describe GroupOrder::Order, type: :model do
  describe 'relations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:group) }
  end

  describe 'validations' do
    it 'is expected to validate that :content is in line with the JSON Schema' do
      order = FactoryBot.build(:group_order_order)
      expect(order).to be_valid

      order.content = nil
      expect(order).not_to be_valid
      expect(order.errors.details).to have_shape(
        {
          content: [
            { error: "The property '#/' of type null did not match the following type: object in schema" }
          ]
        }
      )

      order.content = {}
      expect(order).not_to be_valid
      expect(order.errors.details).to have_shape(
        {
          content: [
            { error: "The property '#/' did not contain a required property of 'items' in schema" }
          ]
        }
      )

      # Maybe we can test more...
    end

    it 'is expected to validate that each item in :content is reachable in the menu of the group' do
      group = FactoryBot.create(
        :group_order_group,
        menu: {
          menu: {
            sectionUuids: %w[s1 s2 s3]
          },
          sections: {
            s1: { name: 'Section 1', itemUuids: %w[i1 i2] },
            s2: { name: 'Section 2', itemUuids: ['i3'] },
            s3: { name: 'Section 3', itemUuids: %w[i1 i5] },
            s4: { name: 'Section 4', itemUuids: ['i6'] } # Not referenced in menu.sectionUuids
          },
          items: {
            i1: { name: 'Item 1', priceSubunits: 0 },
            i2: { name: 'Item 2', priceSubunits: 0 },
            i3: { name: 'Item 3', priceSubunits: 0 },
            i4: { name: 'Item 4', priceSubunits: 0 },  # Not referenced by any section
            i5: { name: 'Item 5', priceSubunits: 0 },
            i6: { name: 'Item 6', priceSubunits: 0 }   # Only referenced by Section 4
          }
        }
      )
      order = FactoryBot.build(:group_order_order, group: group)
      expect(order).to be_valid

      order.content = {
        items: [
          { uuid: 'i1', quantity: 1 },
          { uuid: 'i2', quantity: 1 },
          { uuid: 'i3', quantity: 1 },
          { uuid: 'i5', quantity: 1 }
        ]
      }
      expect(order).to be_valid

      order.content = {
        items: [
          { uuid: 'i2', quantity: 1 },
          { uuid: 'i4', quantity: 1 },
          { uuid: 'i6', quantity: 1 },
          { uuid: 'i7', quantity: 1 }
        ]
      }
      expect(order).not_to be_valid
      expect(order.errors.details).to have_shape(
        {
          content: [
            {
              error: :items_not_avaliable,
              unavaliable_item_uuids: %w[i4 i6 i7],
              unavaliable_item_names: ['Item 4', 'Item 6']
            }
          ]
        }
      )
    end

    it 'is expected to validate that each customization of each item in :content is avaliable for that item in the menu of the group' do
      group = FactoryBot.create(
        :group_order_group,
        menu: {
          menu: {
            sectionUuids: ['sec']
          },
          sections: {
            sec: { name: 'Section', itemUuids: %w[i1 i2] }
          },
          items: {
            i1: { name: 'Item 1', priceSubunits: 0, customizationUuids: %w[c1 c2] },
            i2: { name: 'Item 2', priceSubunits: 0, customizationUuids: %w[c2 c3] }
          },
          customizations: {
            c1: { name: 'Customization 1', optionUuids: %w[o1 o2] },
            c2: { name: 'Customization 2', optionUuids: %w[o2 o3] },
            c3: { name: 'Customization 3', optionUuids: %w[o1 o3] }
          },
          customizationOptions: {
            o1: { name: 'Option 1' },
            o2: { name: 'Option 2' },
            o3: { name: 'Option 3' }
          }
        }
      )
      order = FactoryBot.build(:group_order_order, group: group)
      expect(order).to be_valid

      order.content = {
        items: [
          {
            uuid: 'i1',
            customizations: {
              c1: { options: { o1: { quantity: 1 } } },
              c2: { options: { o2: { quantity: 1 } } }
            },
            quantity: 1
          },
          {
            uuid: 'i2',
            customizations: {
              c2: { options: { o2: { quantity: 1 } } },
              c3: { options: { o3: { quantity: 1 } } }
            },
            quantity: 1
          }
        ]
      }
      expect(order).to be_valid

      order.content = {
        items: [
          {
            uuid: 'i1',
            customizations: {
              c1: { options: { o1: { quantity: 1 } } },
              c3: { options: { o1: { quantity: 1 } } }
            },
            quantity: 1
          },
          {
            uuid: 'i2',
            customizations: {
              c1: { options: { o3: { quantity: 1 } } },
              c3: { options: { o2: { quantity: 1 } } },
              c4: {}
            },
            quantity: 1
          },
          {
            uuid: 'i3',
            customizations: {
              c1: { options: { o1: { quantity: 1 } } }
            },
            quantity: 1
          }
        ]
      }
      expect(order).not_to be_valid
      expect(order.errors.details).to have_shape(
        {
          content: [
            {
              error: :customization_not_avaliable_on_item,
              item_uuid: 'i1',
              item_name: 'Item 1',
              unavaliable_customization_uuids: ['c3'],
              unavaliable_customization_names: ['Customization 3']
            },
            {
              error: :customization_not_avaliable_on_item,
              item_uuid: 'i2',
              item_name: 'Item 2',
              unavaliable_customization_uuids: %w[c1 c4],
              unavaliable_customization_names: ['Customization 1']
            }
          ]
        }
      )
    end

    it 'is expected to validate that each customization option of each item in :content is avaliable for that customization in the menu of the group' do
      group = FactoryBot.create(
        :group_order_group,
        menu: {
          menu: {
            sectionUuids: ['sec']
          },
          sections: {
            sec: { name: 'Section', itemUuids: %w[i1 i2] }
          },
          items: {
            i1: { name: 'Item 1', priceSubunits: 0, customizationUuids: %w[c1 c2 c3] },
            i2: { name: 'Item 2', priceSubunits: 0, customizationUuids: %w[c1 c2 c3] }
          },
          customizations: {
            c1: { name: 'Customization 1', optionUuids: %w[o1 o2] },
            c2: { name: 'Customization 2', optionUuids: %w[o2 o3] },
            c3: { name: 'Customization 3', optionUuids: %w[o1 o3] }
          },
          customizationOptions: {
            o1: { name: 'Option 1' },
            o2: { name: 'Option 2' },
            o3: { name: 'Option 3' }
          }
        }
      )
      order = FactoryBot.build(:group_order_order, group: group)
      expect(order).to be_valid

      order.content = {
        items: [
          {
            uuid: 'i1',
            customizations: {
              c1: { options: { o1: { quantity: 1 } } },
              c2: { options: { o2: { quantity: 1 } } }
            },
            quantity: 1
          },
          {
            uuid: 'i2',
            customizations: {
              c2: { options: { o2: { quantity: 1 } } },
              c3: { options: { o3: { quantity: 1 } } }
            },
            quantity: 1
          }
        ]
      }
      expect(order).to be_valid

      order.content = {
        items: [
          {
            uuid: 'i1',
            customizations: {
              c1: { options: { o1: { quantity: 1 } } },
              c2: { options: { o1: { quantity: 1 } } }
            },
            quantity: 1
          },
          {
            uuid: 'i2',
            customizations: {
              c1: { options: { o3: { quantity: 1 } } },
              c3: { options: { o2: { quantity: 1 }, o5: { quantity: 1 } } }
            },
            quantity: 1
          }
        ]
      }
      expect(order).not_to be_valid
      expect(order.errors.details).to have_shape(
        {
          content: [
            {
              error: :customization_option_not_avaliable_on_customization,
              item_uuid: 'i1',
              item_name: 'Item 1',
              customization_uuid: 'c2',
              customization_name: 'Customization 2',
              unavaliable_option_uuids: ['o1'],
              unavaliable_option_names: ['Option 1']
            },
            {
              error: :customization_option_not_avaliable_on_customization,
              item_uuid: 'i2',
              item_name: 'Item 2',
              customization_uuid: 'c1',
              customization_name: 'Customization 1',
              unavaliable_option_uuids: ['o3'],
              unavaliable_option_names: ['Option 3']
            },
            {
              error: :customization_option_not_avaliable_on_customization,
              item_uuid: 'i2',
              item_name: 'Item 2',
              customization_uuid: 'c3',
              customization_name: 'Customization 3',
              unavaliable_option_uuids: %w[o2 o5],
              unavaliable_option_names: ['Option 2']
            }
          ]
        }
      )
    end

    it "is expected to validate that each item's customization option quantity count in :content is in the minPermitted..maxPermitted range of that customization in the menu of the group" do
      group = FactoryBot.create(
        :group_order_group,
        menu: {
          menu: {
            sectionUuids: ['sec']
          },
          sections: {
            sec: { name: 'Section', itemUuids: %w[i1 i2] }
          },
          items: {
            i1: { name: 'Item 1', priceSubunits: 0, customizationUuids: %w[c1 c2 c3] },
            i2: { name: 'Item 2', priceSubunits: 0, customizationUuids: %w[c1 c2 c3] }
          },
          customizations: {
            c1: {
              name: 'Customization 1',
              optionUuids: %w[o1 o2 o3],
              minPermitted: 1
            },
            c2: {
              name: 'Customization 2',
              optionUuids: %w[o1 o2 o3],
              maxPermitted: 2
            },
            c3: {
              name: 'Customization 3',
              optionUuids: %w[o1 o2 o3],
              minPermitted: 2,
              maxPermitted: 4
            }
          },
          customizationOptions: {
            o1: { name: 'Option 1' },
            o2: { name: 'Option 2' },
            o3: { name: 'Option 3' }
          }
        }
      )
      order = FactoryBot.build(:group_order_order, group: group)
      expect(order).to be_valid

      order.content = {
        items: [
          {
            uuid: 'i1',
            customizations: {
              c1: { options: { o1: { quantity: 10 }, o2: { quantity: 10 } } },
              c3: { options: { o1: { quantity: 1 }, o2: { quantity: 1 } } }
            },
            quantity: 1
          },
          {
            uuid: 'i1',
            customizations: {
              c1: { options: { o1: { quantity: 1 } } },
              c2: { options: { o1: { quantity: 1 }, o2: { quantity: 1 } } },
              c3: { options: { o1: { quantity: 2 } } }
            },
            quantity: 1
          },
          {
            uuid: 'i1',
            customizations: {
              c1: { options: { o1: { quantity: 100 } } },
              c2: { options: { o1: { quantity: 2 } } },
              c3: { options: { o1: { quantity: 4 } } }
            },
            quantity: 1
          }
        ]
      }
      expect(order).to be_valid

      order.content = {
        items: [
          {
            uuid: 'i1',
            customizations: {
              # c1 missing while it's minPermitted is 1
              # c2 goes over the maxPermitted which is 2
              c2: { options: { o1: { quantity: 1 }, o2: { quantity: 1 }, o3: { quantity: 1 } } },
              # c3 goes over the maxPermitted which is 4
              c3: { options: { o1: { quantity: 2 }, o2: { quantity: 3 } } }
            },
            quantity: 1
          },
          {
            uuid: 'i2',
            customizations: {
              c1: { options: { o3: { quantity: 1 } } },
              # c2 goes over the maxPermitted which is 2
              c2: { options: { o1: { quantity: 3 } } },
              # c3 goes under the minPermitted which is 2
              c3: { options: { o1: { quantity: 1 } } }
            },
            quantity: 1
          }
        ]
      }
      expect(order).not_to be_valid
      expect(order.errors.details).to have_shape(
        {
          content: [
            {
              error: :customization_options_count_less_then_min_permitted,
              item_uuid: 'i1',
              item_name: 'Item 1',
              customization_uuid: 'c1',
              customization_name: 'Customization 1',
              min_permitted_options_count: 1,
              selected_options_count: 0
            },
            {
              error: :customization_options_count_more_then_max_permitted,
              item_uuid: 'i1',
              item_name: 'Item 1',
              customization_uuid: 'c2',
              customization_name: 'Customization 2',
              max_permitted_options_count: 2,
              selected_options_count: 3
            },
            {
              error: :customization_options_count_more_then_max_permitted,
              item_uuid: 'i1',
              item_name: 'Item 1',
              customization_uuid: 'c3',
              customization_name: 'Customization 3',
              max_permitted_options_count: 4,
              selected_options_count: 5
            },
            {
              error: :customization_options_count_more_then_max_permitted,
              item_uuid: 'i2',
              item_name: 'Item 2',
              customization_uuid: 'c2',
              customization_name: 'Customization 2',
              max_permitted_options_count: 2,
              selected_options_count: 3
            },
            {
              error: :customization_options_count_less_then_min_permitted,
              item_uuid: 'i2',
              item_name: 'Item 2',
              customization_uuid: 'c3',
              customization_name: 'Customization 3',
              min_permitted_options_count: 2,
              selected_options_count: 1
            }
          ]
        }
      )

      order.content = {
        items: [
          {
            uuid: 'i1',
            # No customizations are selected while customizations c1 and c3 has minPermitted
            quantity: 1
          }
        ]
      }
      expect(order).not_to be_valid
      expect(order.errors.details).to have_shape(
        {
          content: [
            {
              error: :customization_options_count_less_then_min_permitted,
              item_uuid: 'i1',
              item_name: 'Item 1',
              customization_uuid: 'c1',
              customization_name: 'Customization 1',
              min_permitted_options_count: 1,
              selected_options_count: 0
            },
            {
              error: :customization_options_count_less_then_min_permitted,
              item_uuid: 'i1',
              item_name: 'Item 1',
              customization_uuid: 'c3',
              customization_name: 'Customization 3',
              min_permitted_options_count: 2,
              selected_options_count: 0
            }
          ]
        }
      )
    end

    it "is expected to validate that each item's customization option quantity in :content is in the minPermitted..maxPermitted range of that option in the menu of the group" do
      group = FactoryBot.create(
        :group_order_group,
        menu: {
          menu: {
            sectionUuids: ['sec']
          },
          sections: {
            sec: { name: 'Section', itemUuids: %w[i1 i2] }
          },
          items: {
            i1: { name: 'Item 1', priceSubunits: 0, customizationUuids: %w[c1 c2] },
            i2: { name: 'Item 2', priceSubunits: 0, customizationUuids: %w[c1 c2] }
          },
          customizations: {
            c1: { name: 'Customization 1', optionUuids: %w[o1 o2 o3] },
            c2: { name: 'Customization 2', optionUuids: %w[o1 o2 o3] }
          },
          customizationOptions: {
            o1: {
              name: 'Option 1',
              minPermitted: 1
            },
            o2: {
              name: 'Option 2',
              maxPermitted: 3
            },
            o3: {
              name: 'Option 3',
              minPermitted: 2,
              maxPermitted: 4
            }
          }
        }
      )
      order = FactoryBot.build(:group_order_order, group: group)
      expect(order).to be_valid

      order.content = {
        items: [
          {
            uuid: 'i1',
            customizations: {
              c1: {
                options: {
                  o1: { quantity: 1 },
                  o2: { quantity: 3 },
                  o3: { quantity: 2 }
                }
              },
              c2: {
                options: {
                  o1: { quantity: 1000 },
                  o3: { quantity: 4 }
                }
              }
            },
            quantity: 1
          }
        ]
      }
      expect(order).to be_valid

      order.content = {
        items: [
          {
            uuid: 'i1',
            customizations: {
              c1: {
                options: {
                  # o1 missing while it's minPermitted is 1
                  # o2 goes over the maxPermitted which is 3
                  o2: { quantity: 4 },
                  # o3 goes under the minPermitted which is 2
                  o3: { quantity: 1 }
                }
              },
              c2: {
                options: {
                  o1: { quantity: 1 },
                  o2: { quantity: 3 },
                  # o3 goes over the maxPermitted which is 4
                  o3: { quantity: 5 }
                }
              }
            },
            quantity: 1
          }
        ]
      }
      expect(order).not_to be_valid
      expect(order.errors.details).to have_shape(
        {
          content: [
            {
              error: :customization_option_quantity_less_then_min_permitted,
              item_uuid: 'i1',
              item_name: 'Item 1',
              customization_uuid: 'c1',
              customization_name: 'Customization 1',
              option_uuid: 'o1',
              option_name: 'Option 1',
              min_permitted_quantity: 1,
              selected_quantity: 0
            },
            {
              error: :customization_option_quantity_more_then_max_permitted,
              item_uuid: 'i1',
              item_name: 'Item 1',
              customization_uuid: 'c1',
              customization_name: 'Customization 1',
              option_uuid: 'o2',
              option_name: 'Option 2',
              max_permitted_quantity: 3,
              selected_quantity: 4
            },
            {
              error: :customization_option_quantity_less_then_min_permitted,
              item_uuid: 'i1',
              item_name: 'Item 1',
              customization_uuid: 'c1',
              customization_name: 'Customization 1',
              option_uuid: 'o3',
              option_name: 'Option 3',
              min_permitted_quantity: 2,
              selected_quantity: 1
            },
            {
              error: :customization_option_quantity_more_then_max_permitted,
              item_uuid: 'i1',
              item_name: 'Item 1',
              customization_uuid: 'c2',
              customization_name: 'Customization 2',
              option_uuid: 'o3',
              option_name: 'Option 3',
              max_permitted_quantity: 4,
              selected_quantity: 5
            }
          ]
        }
      )

      order.content = {
        items: [
          {
            uuid: 'i2',
            # Does not select any customizations while customizations c1 and c2 has required minPermitted options
            quantity: 1
          }
        ]
      }
      expect(order).not_to be_valid
      expect(order.errors.details).to have_shape(
        {
          content: [
            {
              error: :customization_option_quantity_less_then_min_permitted,
              item_uuid: 'i2',
              item_name: 'Item 2',
              customization_uuid: 'c1',
              customization_name: 'Customization 1',
              option_uuid: 'o1',
              option_name: 'Option 1',
              min_permitted_quantity: 1,
              selected_quantity: 0
            },
            {
              error: :customization_option_quantity_less_then_min_permitted,
              item_uuid: 'i2',
              item_name: 'Item 2',
              customization_uuid: 'c1',
              customization_name: 'Customization 1',
              option_uuid: 'o3',
              option_name: 'Option 3',
              min_permitted_quantity: 2,
              selected_quantity: 0
            },
            {
              error: :customization_option_quantity_less_then_min_permitted,
              item_uuid: 'i2',
              item_name: 'Item 2',
              customization_uuid: 'c2',
              customization_name: 'Customization 2',
              option_uuid: 'o1',
              option_name: 'Option 1',
              min_permitted_quantity: 1,
              selected_quantity: 0
            },
            {
              error: :customization_option_quantity_less_then_min_permitted,
              item_uuid: 'i2',
              item_name: 'Item 2',
              customization_uuid: 'c2',
              customization_name: 'Customization 2',
              option_uuid: 'o3',
              option_name: 'Option 3',
              min_permitted_quantity: 2,
              selected_quantity: 0
            }
          ]
        }
      )
    end
  end

  describe 'calculated content or attributes' do
    let(:group) do
      FactoryBot.create(
        :group_order_group,
        menu: {
          menu: {
            sectionUuids: %w[s1 s2 s3]
          },
          sections: {
            s1: { name: 'Section 1', itemUuids: %w[i1 i2] },
            s2: { name: 'Section 2', itemUuids: %w[i3 i4] },
            s3: { name: 'Section 3', itemUuids: %w[i5] }
          },
          items: {
            i1: { name: 'Item 1', priceSubunits: 100_00, customizationUuids: %w[c1 c2 c3] },
            i2: { name: 'Item 2', priceSubunits: 200_00, customizationUuids: %w[c1 c2 c3] },
            i3: { name: 'Item 3', priceSubunits: 300_00, customizationUuids: %w[c1 c2 c3] },
            i4: { name: 'Item 4', priceSubunits: 400_00, customizationUuids: %w[c1 c2 c3] },
            i5: { name: 'Item 5', priceSubunits: 500_00, customizationUuids: %w[c1 c2 c3] }
          },
          customizations: {
            c1: { name: 'Customization 1', optionUuids: %w[o1 o2] },
            c2: { name: 'Customization 2', optionUuids: %w[o2 o3 o4] },
            c3: { name: 'Customization 3', optionUuids: %w[o3 o4 o5] }
          },
          customizationOptions: {
            o1: { name: 'Option 1' },
            o2: { name: 'Option 2' },
            o3: { name: 'Option 3', priceSubunits: 10_00 },
            o4: { name: 'Option 4', priceSubunits: 20_00 },
            o5: { name: 'Option 5', priceSubunits: 30_00 }
          }
        }
      )
    end

    it 'calculates and fills the :amount by :content' do
      order = FactoryBot.build(
        :group_order_order,
        group: group,
        content: {
          'items' => [
            { 'uuid' => 'i1', 'quantity' => 1 }
          ]
        }
      )
      expect(order).to be_valid
      expect(order.amount).to eq(Money.from_amount(100))

      order = FactoryBot.build(
        :group_order_order,
        group: group,
        content: {
          'items' => [
            {
              'uuid' => 'i1',
              'customizations' => {
                'c1' => {
                  'options' => {
                    'o1' => { 'quantity': 1 },
                    'o2' => { 'quantity': 2 }
                  }
                },
                'c3' => {
                  'options' => {
                    'o3' => { 'quantity': 5 },
                    'o4' => { 'quantity': 1 }
                  }
                }
              },
              'quantity' => 1
            }
          ]
        }
      )
      expect(order).to be_valid
      expect(order.amount).to eq(Money.from_amount(170))

      order.content['items'][0]['quantity'] = 2
      expect(order).to be_valid
      expect(order.amount).to eq(Money.from_amount(170 * 2))

      order.content['items'].push order.content['items'][0]
      expect(order).to be_valid
      expect(order.amount).to eq(Money.from_amount(170 * 4))

      order.content['items'][0]['quantity'] = 3
      expect(order).to be_valid
      expect(order.amount).to eq(Money.from_amount(170 * 3 + 170 * 2))

      order.content['items'][0]['customizations']['c3']['options']['o5'] = { 'quantity' => 10 }
      expect(order).to be_valid
      expect(order.amount).to eq(Money.from_amount((170 + 300) * 3 + 170 * 2))
    end

    it 'calculates and fills the `name` for every item in :content before validation' do
      order = FactoryBot.build(
        :group_order_order,
        group: group,
        content: {
          'items' => [
            { 'uuid' => 'i1', 'quantity' => 1, 'name' => 'This should be ignored' },
            { 'uuid' => 'i1', 'quantity' => 2 },
            { 'uuid' => 'i3', 'quantity' => 3 },
            { 'uuid' => 'i2', 'quantity' => 4 },
            { 'uuid' => 'i1', 'quantity' => 5 },
            { 'uuid' => 'i4', 'quantity' => 1 },
            { 'uuid' => 'i5', 'quantity' => 2 }
          ]
        }
      )
      expect(order).to be_valid
      expect(order.content['items']).to have_shape(
        [
          { 'uuid' => 'i1', 'quantity' => 1, 'name' => 'Item 1' },
          { 'uuid' => 'i1', 'quantity' => 2, 'name' => 'Item 1' },
          { 'uuid' => 'i3', 'quantity' => 3, 'name' => 'Item 3' },
          { 'uuid' => 'i2', 'quantity' => 4, 'name' => 'Item 2' },
          { 'uuid' => 'i1', 'quantity' => 5, 'name' => 'Item 1' },
          { 'uuid' => 'i4', 'quantity' => 1, 'name' => 'Item 4' },
          { 'uuid' => 'i5', 'quantity' => 2, 'name' => 'Item 5' }
        ]
      )
    end

    it 'calculates and fills the `price` for every item in :content before validation' do
      order = FactoryBot.build(
        :group_order_order,
        group: group,
        content: {
          'items' => [
            # priceSubunits on items should be ignored
            { 'uuid' => 'i1', 'quantity' => 1, 'priceSubunits' => 900_00 },
            { 'uuid' => 'i2', 'quantity' => 2 },
            { 'uuid' => 'i3', 'quantity' => 3 },
            { 'uuid' => 'i4', 'quantity' => 4 },
            { 'uuid' => 'i5', 'quantity' => 5 }
          ]
        }
      )
      expect(order).to be_valid
      expect(order.content['items']).to have_shape(
        [
          { 'uuid' => 'i1', 'quantity' => 1, 'priceSubunits' => 100_00 },
          { 'uuid' => 'i2', 'quantity' => 2, 'priceSubunits' => 200_00 },
          { 'uuid' => 'i3', 'quantity' => 3, 'priceSubunits' => 300_00 },
          { 'uuid' => 'i4', 'quantity' => 4, 'priceSubunits' => 400_00 },
          { 'uuid' => 'i5', 'quantity' => 5, 'priceSubunits' => 500_00 }
        ]
      )
    end

    it 'calculates and fills the `name` for every customization for every `item` in :content before validation' do
      order = FactoryBot.build(
        :group_order_order,
        group: group,
        content: {
          'items' => [
            {
              'uuid' => 'i1',
              'quantity' => 1,
              'customizations' => {
                'c1' => {
                  'name' => 'This should be ignored',
                  'options' => {
                    'o1' => { 'quantity' => 1 }
                  }
                },
                'c2' => {
                  'options' => {
                    'o2' => { 'quantity' => 1 }
                  }
                }
              }
            },
            {
              'uuid' => 'i2',
              'quantity' => 2,
              'customizations' => {
                'c3' => {
                  'options' => {
                    'o3' => { 'quantity' => 1 }
                  }
                }
              }
            }
          ]
        }
      )
      expect(order).to be_valid
      expect(order.content['items']).to have_shape(
        [
          {
            'uuid' => 'i1',
            'quantity' => 1,
            'customizations' => {
              'c1' => { 'name' => 'Customization 1' },
              'c2' => { 'name' => 'Customization 2' }
            }
          },
          {
            'uuid' => 'i2',
            'quantity' => 2,
            'customizations' => {
              'c3' => { 'name' => 'Customization 3' }
            }
          }
        ]
      )
    end

    it 'calculates and fills the `name` for every option for every customization for every `item` in :content before validation' do
      order = FactoryBot.build(
        :group_order_order,
        group: group,
        content: {
          'items' => [
            {
              'uuid' => 'i1',
              'quantity' => 1,
              'customizations' => {
                'c1' => {
                  'options' => {
                    'o1' => { 'quantity' => 1, 'name' => 'This should be ignored' }
                  }
                },
                'c2' => {
                  'options' => {
                    'o2' => { 'quantity' => 2 }
                  }
                }
              }
            },
            {
              'uuid' => 'i2',
              'quantity' => 2,
              'customizations' => {
                'c3' => {
                  'options' => {
                    'o3' => { 'quantity' => 3 },
                    'o4' => { 'quantity' => 4 },
                    'o5' => { 'quantity' => 5 }
                  }
                }
              }
            }
          ]
        }
      )
      expect(order).to be_valid
      expect(order.content['items']).to have_shape(
        [
          {
            'uuid' => 'i1',
            'quantity' => 1,
            'customizations' => {
              'c1' => {
                'options' => {
                  'o1' => { 'quantity' => 1, 'name' => 'Option 1' }
                }
              },
              'c2' => {
                'options' => {
                  'o2' => { 'quantity' => 2, 'name' => 'Option 2' }
                }
              }
            }
          },
          {
            'uuid' => 'i2',
            'quantity' => 2,
            'customizations' => {
              'c3' => {
                'options' => {
                  'o3' => { 'quantity' => 3, 'name' => 'Option 3' },
                  'o4' => { 'quantity' => 4, 'name' => 'Option 4' },
                  'o5' => { 'quantity' => 5, 'name' => 'Option 5' }
                }
              }
            }
          }
        ]
      )
    end

    it 'calculates and fills the `priceSubunits` for every option for every customization for every item in :content before validation' do
      order = FactoryBot.build(
        :group_order_order,
        group: group,
        content: {
          'items' => [
            {
              'uuid' => 'i1',
              'quantity' => 1,
              'customizations' => {
                'c1' => {
                  'options' => {
                    # priceSubunits should be removed
                    'o1' => { 'quantity' => 1, 'priceSubunits' => 10_00 }
                  }
                },
                'c2' => {
                  'options' => {
                    'o2' => { 'quantity' => 2 }
                  }
                }
              }
            },
            {
              'uuid' => 'i2',
              'quantity' => 2,
              'customizations' => {
                'c3' => {
                  'options' => {
                    'o3' => { 'quantity' => 3 },
                    'o4' => { 'quantity' => 4 },
                    'o5' => { 'quantity' => 5 }
                  }
                }
              }
            }
          ]
        }
      )
      expect(order).to be_valid
      o1 = order.content.dig('items', 0, 'customizations', 'c1', 'options', 'o1')
      expect(o1['quantity']).to eq(1)
      expect(o1).not_to have_key('priceSubunits')
      o2 = order.content.dig('items', 0, 'customizations', 'c2', 'options', 'o2')
      expect(o2['quantity']).to eq(2)
      expect(o2).not_to have_key('priceSubunits')
      expect(order.content['items']).to have_shape(
        [
          {
            'uuid' => 'i2',
            'quantity' => 2,
            'customizations' => {
              'c3' => {
                'options' => {
                  'o3' => { 'quantity' => 3, 'priceSubunits' => 10_00 },
                  'o4' => { 'quantity' => 4, 'priceSubunits' => 20_00 },
                  'o5' => { 'quantity' => 5, 'priceSubunits' => 30_00 }
                }
              }
            }
          }
        ]
      )
    end
  end
end
# rubocop:enable Layout/LineLength
