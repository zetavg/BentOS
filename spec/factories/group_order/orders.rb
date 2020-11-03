# frozen_string_literal: true

FactoryBot.define do
  factory :group_order_order, class: 'GroupOrder::Order' do
    user { association :user, :confirmed }
    group { association :group_order_group }

    content do
      menu = group&.menu || {}
      avaliable_items = group&.avaliable_menu_items || {}

      {
        items:
          Array.new(rand(1..[avaliable_items.length, 2].min) || 0)
               .map { avaliable_items.to_a.sample }
               .map do |uuid, item|
                 c_uuids = item['customizationUuids'] || []

                 avaliable_customizations = c_uuids.map { |c_uuid| [c_uuid, menu.dig('customizations', c_uuid)] }
                 selected_customizations = avaliable_customizations.filter do |_, customization|
                   customization_options =
                     (customization['optionUuids'] || []).map { |o_uuid| menu.dig('customizationOptions', o_uuid) }
                                                         .filter { |o| o.is_a? Hash }
                   (customization['minPermitted'] || 0) > 0 ||
                     customization_options.map { |o| o['minPermitted'] || 0 }.any? { |n| n > 0 } ||
                     rand(0..2) > 1
                 end

                 {
                   uuid: uuid,
                   quantity: rand(1..3),
                   customizations: Hash[
                     selected_customizations.map do |c_uuid, customization|
                       o_uuids = customization['optionUuids'] || []
                       options = o_uuids.map { |o_uuid| [o_uuid, menu.dig('customizationOptions', o_uuid)] }

                       # Init the ordered options with the min allowed quantity of each option selected
                       # rubocop:disable Style/HashTransformValues
                       selected_order_options = Hash[
                         options.filter { |_, o| (o['minPermitted'] || 0) > 0 }
                                .map { |o_uuid, o| [o_uuid, { 'quantity' => o['minPermitted'] }] }
                       ]
                       # rubocop:enable Style/HashTransformValues

                       number_of_options_currently_selected =
                         selected_order_options.to_a.map { |_, o| o['quantity'] }.compact.sum

                       additional_options_needed = 0
                       if customization['minPermitted']
                         additional_options_needed =
                           customization['minPermitted'] - number_of_options_currently_selected
                       end
                       additional_options_needed = 0 if additional_options_needed < 0

                       additional_options_allowed = Float::INFINITY
                       if customization['maxPermitted']
                         additional_options_allowed =
                           customization['maxPermitted'] - number_of_options_currently_selected
                       end
                       additional_options_allowed = 0 if additional_options_allowed < 0

                       (
                         rand(
                           additional_options_needed..[
                             additional_options_needed + rand(0..3), additional_options_allowed
                           ].min
                         ) || 0
                       ).times do
                         options_available_to_select =
                           options.filter do |o_uuid, o|
                             max_permitted_quantity = o['maxPermitted'] || Float::INFINITY
                             currently_selected_quantity = selected_order_options.dig(o_uuid, 'quantity') || 0
                             currently_selected_quantity < max_permitted_quantity
                           end
                         option_uuids_available_to_select = options_available_to_select.map { |id, _| id }

                         option_uuid_to_select = option_uuids_available_to_select.sample

                         o = selected_order_options[option_uuid_to_select] ||= { 'quantity' => 0 }
                         o['quantity'] += 1
                       end

                       [
                         c_uuid,
                         {
                           options: selected_order_options
                         }
                       ]
                     end
                   ]
                 }
               end
      }
    end
    private { false }

    to_create do |order|
      order_placement = GroupOrder::OrderPlacement.new(user: order.user, group: order.group, content: order.content)
      order_placement.save!
      order.id = order_placement.order.id
      order.reload
    end
  end
end
