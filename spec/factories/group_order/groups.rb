# frozen_string_literal: true

FactoryBot.define do
  factory :group_order_group, class: 'GroupOrder::Group' do
    organizer { association :user, :confirmed }

    name { Faker::Restaurant.name }
    private { false }
    menu do
      {
        menu: {
          sectionUuids: %w[
            97e62a8c-676a-4373-8d8a-32ffcb2b511d
            b4d2a3e6-16f3-44d9-9f05-55f28a939fbb
          ]
        },
        sections: {
          '97e62a8c-676a-4373-8d8a-32ffcb2b511d': {
            name: 'Bentos',
            itemUuids: %w[
              eead727c-fb98-49e5-b327-588f679067bb
              9ff75235-460e-4a54-b6e0-3e39d4790d09
            ]
          },
          'b4d2a3e6-16f3-44d9-9f05-55f28a939fbb': {
            name: 'Drinks',
            itemUuids: %w[
              d6a5a154-10a3-4141-9fca-155993136339
              5ec35b29-0288-4555-85ee-816101650c70
            ]
          }
        },
        items: {
          'eead727c-fb98-49e5-b327-588f679067bb': {
            name: 'Bento',
            description: 'The most advanced bento.',
            priceSubunits: 120_00, # 120.00
            customizationUuids: %w[
              a32088af-0bf0-46bc-a4ed-ed6ec477348d
              208d63e1-e1ea-4ab6-baea-bcbd16865a0f
            ]
          },
          '9ff75235-460e-4a54-b6e0-3e39d4790d09': {
            name: 'Bento Pro',
            description: 'The most advanced bento, pro.',
            priceSubunits: 150_00, # 150.00
            customizationUuids: %w[
              a32088af-0bf0-46bc-a4ed-ed6ec477348d
              208d63e1-e1ea-4ab6-baea-bcbd16865a0f
            ]
          },
          'd6a5a154-10a3-4141-9fca-155993136339': {
            name: 'Black Tea',
            priceSubunits: 30_00 # 30.00
          },
          '5ec35b29-0288-4555-85ee-816101650c70': {
            name: 'Green Tea',
            priceSubunits: 30_00 # 30.00
          }
        },
        customizations: {
          'a32088af-0bf0-46bc-a4ed-ed6ec477348d': {
            name: 'Main dish',
            minPermitted: 1,
            maxPermitted: 1,
            optionUuids: %w[
              1eba3bc2-c8af-4dff-9c0a-6ec654d3a161
              ac2aa9b0-52e5-432a-b4c9-7a8bf281ecc0
              a51a08c8-05c3-4a60-9123-5228e91bb69c
              5ec2d996-c606-4fe2-832b-fe69e3f81563
            ]
          },
          '1f628ea6-9270-43d1-badd-3e2b7d843552': {
            name: 'Side dishes',
            minPermitted: 3,
            maxPermitted: 3,
            optionUuids: %w[
              70629c9a-9f91-4f53-ae4e-b74c90e7509d
              4afbb1b5-4d76-405a-ad6d-5757eedc4c33
              ea13f322-2172-4f4e-9b0d-65a6e5d6d86c
              e919e4dc-9213-4725-85bf-1f9d24a3f4ef
            ]
          },
          '208d63e1-e1ea-4ab6-baea-bcbd16865a0f': {
            name: 'Sauce',
            minPermitted: 0,
            maxPermitted: 1,
            optionUuids: %w[
              3fdf7dcd-8862-4373-bb5f-d132cddbf638
              dcdc80b0-6803-42db-a6ac-6b3936f683ce
              11eb884e-fb93-4f58-bee3-56af2696f7d3
            ]
          },
          '87612ee8-a30c-4d0b-a045-59fc403f2682': {
            name: 'Addons',
            minPermitted: 0,
            maxPermitted: 3,
            optionUuids: %w[
              83884d6c-0099-4a31-bf09-e1a800e8eb67
              4d0b934c-49e6-40b8-bec3-f918939c12f4
              faff10aa-087f-4fbf-9e64-e17a8b67f205
              30f3e875-1681-438f-b20f-e025920396d4
            ]
          }
        },
        customizationOptions: {
          '1eba3bc2-c8af-4dff-9c0a-6ec654d3a161': {
            name: 'Beef',
            defaultQuantity: 0,
            minPermitted: 0,
            maxPermitted: 1
          },
          'ac2aa9b0-52e5-432a-b4c9-7a8bf281ecc0': {
            name: 'Pork',
            defaultQuantity: 0,
            minPermitted: 0,
            maxPermitted: 1
          },
          'a51a08c8-05c3-4a60-9123-5228e91bb69c': {
            name: 'Chicken',
            defaultQuantity: 0,
            minPermitted: 0,
            maxPermitted: 1
          },
          '5ec2d996-c606-4fe2-832b-fe69e3f81563': {
            name: 'Fish',
            defaultQuantity: 0,
            minPermitted: 0,
            maxPermitted: 1,
            priceSubunits: 12_00 # 12.00
          },
          '70629c9a-9f91-4f53-ae4e-b74c90e7509d': {
            name: 'Mashed potatoes',
            defaultQuantity: 0,
            minPermitted: 0,
            maxPermitted: 1
          },
          '4afbb1b5-4d76-405a-ad6d-5757eedc4c33': {
            name: 'Cabbage',
            defaultQuantity: 0,
            minPermitted: 0,
            maxPermitted: 1
          },
          'e919e4dc-9213-4725-85bf-1f9d24a3f4ef': {
            name: 'Broccoli',
            defaultQuantity: 0,
            minPermitted: 0,
            maxPermitted: 1
          },
          'ea13f322-2172-4f4e-9b0d-65a6e5d6d86c': {
            name: 'Dried Tofu',
            defaultQuantity: 0,
            minPermitted: 0,
            maxPermitted: 1,
            priceSubunits: 10_00 # 10.00
          },
          '3fdf7dcd-8862-4373-bb5f-d132cddbf638': {
            name: 'Japanese style sauce',
            defaultQuantity: 0,
            minPermitted: 0,
            maxPermitted: 1
          },
          'dcdc80b0-6803-42db-a6ac-6b3936f683ce': {
            name: 'Flax sauce',
            defaultQuantity: 0,
            minPermitted: 0,
            maxPermitted: 1
          },
          '11eb884e-fb93-4f58-bee3-56af2696f7d3': {
            name: 'lettuce salad',
            defaultQuantity: 0,
            minPermitted: 0,
            maxPermitted: 2,
            priceSubunits: 20_00 # 20.00
          },
          '83884d6c-0099-4a31-bf09-e1a800e8eb67': {
            name: 'Potato cake',
            defaultQuantity: 0,
            minPermitted: 0,
            maxPermitted: 2,
            priceSubunits: 20_00 # 20.00
          },
          '4d0b934c-49e6-40b8-bec3-f918939c12f4': {
            name: 'Fruits',
            defaultQuantity: 0,
            minPermitted: 0,
            maxPermitted: 2,
            priceSubunits: 30_00 # 30.00
          },
          'faff10aa-087f-4fbf-9e64-e17a8b67f205': {
            name: 'Chawanmushi',
            defaultQuantity: 0,
            minPermitted: 0,
            maxPermitted: 2,
            priceSubunits: 25_00 # 25.00
          },
          '30f3e875-1681-438f-b20f-e025920396d4': {
            name: 'Soybeans',
            defaultQuantity: 0,
            minPermitted: 0,
            maxPermitted: 2,
            priceSubunits: 10_00 # 10.00
          }
        }
      }
    end
    to_be_closed_at { 2.days.from_now.midnight }
    expected_delivery_time { 3.days.from_now.noon }
    group_minimum_amount { Money.new(0) }
    group_minimum_sets { 1 }
  end
end
