# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Layout/LineLength
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

    it 'is expected to validate that :state is immutable' do
      group = FactoryBot.build(:group_order_group)
      expect(group).to be_valid

      group.state = :locked
      expect(group).not_to be_valid
      expect(group.errors.details).to have_shape({ base: [{ error: :immutable, changed_attribute_names: [:state] }] })

      group.state = :open # initial state should be accepted
      expect(group).to be_valid
      group.save!

      group.state = :locked
      expect(group).not_to be_valid
      expect(group.errors.details).to have_shape({ base: [{ error: :immutable, changed_attribute_names: [:state] }] })
    end

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
          sectionUuids: %w[a b c]
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
          sectionUuids: %w[a b c]
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
          sectionUuids: %w[foo bar]
        },
        sections: {
          foo: { name: 'A', itemUuids: %w[a b] },
          bar: { name: 'A', itemUuids: %w[b c] }
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
          sectionUuids: %w[foo bar]
        },
        sections: {
          foo: { name: 'A', itemUuids: %w[a b] },
          bar: { name: 'A', itemUuids: %w[b c] }
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
          sec: { name: 'Section', itemUuids: %w[foo bar] }
        },
        items: {
          foo: { name: 'Foo', priceSubunits: 0, customizationUuids: %w[a b] },
          bar: { name: 'Bar', priceSubunits: 0, customizationUuids: %w[a c] }
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
          sec: { name: 'Section', itemUuids: %w[foo bar] }
        },
        items: {
          foo: { name: 'Foo', priceSubunits: 0, customizationUuids: %w[a b] },
          bar: { name: 'Bar', priceSubunits: 0, customizationUuids: %w[a c] }
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
          sec: { name: 'Section', itemUuids: %w[foo bar] }
        },
        items: {
          foo: { name: 'Foo', priceSubunits: 0, customizationUuids: %w[a b] },
          bar: { name: 'Bar', priceSubunits: 0, customizationUuids: %w[a c] }
        }
      }
      expect(group).not_to be_valid
      expect(group.errors.details).to have_shape(
        {
          menu: [
            { error: :customizations_missing, missing_customization_uuids: %w[a b c] }
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
          ite: { name: 'Item', priceSubunits: 0, customizationUuids: %w[foo bar] }
        },
        customizations: {
          foo: { name: 'Customization', optionUuids: %w[a b] },
          bar: { name: 'Customization', optionUuids: %w[a c] }
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
          ite: { name: 'Item', priceSubunits: 0, customizationUuids: %w[foo bar] }
        },
        customizations: {
          foo: { name: 'Customization', optionUuids: %w[a b] },
          bar: { name: 'Customization', optionUuids: %w[a c] }
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

    it "is expected to validate that all for all customizations in :menu, the sum of it's option's minPermitted isn't bigger then the customization's maxPermitted" do
      group = FactoryBot.build(:group_order_group)
      group.menu = {
        menu: {
          sectionUuids: ['sec']
        },
        sections: {
          sec: { name: 'Section', itemUuids: ['ite'] }
        },
        items: {
          ite: { name: 'Item', priceSubunits: 0, customizationUuids: %w[c1 c2 c3] }
        },
        customizations: {
          c1: { name: 'Customization 1', optionUuids: %w[o1], maxPermitted: 1 },
          c2: { name: 'Customization 2', optionUuids: %w[o1 o2], maxPermitted: 2 },
          c3: { name: 'Customization 3', optionUuids: %w[o1 o2 o3 o4 o5] }
        },
        customizationOptions: {
          o1: { name: 'Option 1', minPermitted: 1 },
          o2: { name: 'Option 2', minPermitted: 2 },
          o3: { name: 'Option 3', minPermitted: 3 }
        }
      }
      expect(group).not_to be_valid
      expect(group.errors.details).to have_shape(
        {
          menu: [
            {
              error: :customization_option_min_permitted_conflicts_with_customization_max_permitted,
              customization_uuids: %w[c2]
            }
          ]
        }
      )
    end
  end

  describe '#avaliable_menu_items' do
    it 'returns menu items that are reachable from the menu' do
      group = FactoryBot.build(:group_order_group)
      group.menu = {
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

      expect(group.avaliable_menu_items).to have_shape(
        {
          'i1' => { 'name' => 'Item 1', 'priceSubunits' => 0 },
          'i2' => { 'name' => 'Item 2', 'priceSubunits' => 0 },
          'i3' => { 'name' => 'Item 3', 'priceSubunits' => 0 },
          'i5' => { 'name' => 'Item 5', 'priceSubunits' => 0 }
        }
      )
    end
  end

  describe 'state machine' do
    describe 'states' do
      let(:state) { :open }
      subject(:group) do
        group = FactoryBot.create(
          :group_order_group,
          name: 'Hello Group',
          state: state,
          menu: menu,
          _really_update: true
        )
        group._really_update = false
        group
      end
      let(:menu) do
        {
          menu: {
            sectionUuids: %w[s1]
          },
          sections: {
            s1: { name: 'Section 1', itemUuids: %w[i1] }
          },
          items: {
            i1: { name: 'Item 1', priceSubunits: 0 }
          }
        }
      end

      shared_examples ':name immutable' do
        it 'validates that :name is not changed' do
          subject.name = 'Hello Group'
          expect(subject).to be_valid

          subject.name = 'Hi Group'
          expect(subject).not_to be_valid
          expect(subject.errors.details).to have_shape(
            {
              base: [
                {
                  error: :immutable,
                  changed_attribute_names: [:name]
                }
              ]
            }
          )
        end
      end

      shared_examples ':name mutable' do
        it 'allows :menu to be changed' do
          subject.name = 'Hi Group'
          expect(subject).to be_valid
        end
      end

      shared_examples ':menu immutable' do
        it 'validates that :menu is not changed' do
          subject.menu = menu.clone
          expect(subject).to be_valid

          subject.menu = {
            menu: {
              sectionUuids: %w[s1]
            },
            sections: {
              s1: { name: 'Changed Section 1', itemUuids: %w[i1] }
            },
            items: {
              i1: { name: 'Changed Item 1', priceSubunits: 0 }
            }
          }
          expect(subject).not_to be_valid
          expect(subject.errors.details).to have_shape(
            {
              base: [
                {
                  error: :immutable,
                  changed_attribute_names: [:menu]
                }
              ]
            }
          )
        end
      end

      shared_examples ':menu mutable' do
        it 'allows :menu to be changed' do
          subject.menu = {
            menu: {
              sectionUuids: %w[s1]
            },
            sections: {
              s1: { name: 'Changed Section 1', itemUuids: %w[i1] }
            },
            items: {
              i1: { name: 'Changed Item 1', priceSubunits: 0 }
            }
          }
          expect(subject).to be_valid
        end
      end

      describe 'open' do
        let(:state) { :open }

        it_behaves_like ':name mutable'
        it_behaves_like ':menu mutable'
      end

      describe 'locked' do
        let(:state) { :locked }

        it_behaves_like ':name mutable'
        it_behaves_like ':menu mutable'
      end

      describe 'scheduled' do
        let(:state) { :scheduled }

        it_behaves_like ':name immutable'
        it_behaves_like ':menu immutable'
      end

      describe 'arrived' do
        let(:state) { :arrived }

        it_behaves_like ':name immutable'
        it_behaves_like ':menu immutable'
      end

      describe 'completed' do
        let(:state) { :completed }

        it_behaves_like ':menu immutable'
      end

      describe 'canceled' do
        let(:state) { :canceled }

        it_behaves_like ':menu immutable'
      end
    end
  end
end
# rubocop:enable Layout/LineLength
