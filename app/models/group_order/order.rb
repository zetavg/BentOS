# frozen_string_literal: true

require Rails.root.join('lib', 'schemas', 'menu_order_schema')

# TODO: Try to refactor this
# rubocop:disable Metrics/ClassLength
class GroupOrder::Order < ApplicationRecord
  include AASM
  include Immutable

  aasm column: :state, create_scopes: false, whiny_persistence: true do
    state :placed, initial: true
    state :locked
    state :scheduled
    state :arrived
    state :completed
    state :canceled
  end

  # rubocop:disable Layout/LineLength
  immutable message: 'GroupOrder::Order is not meant to be edited directly, please use `GroupOrder::OrderPlacement` to place a new order and use `GroupOrder::OrderUpdate` to update an existing order'
  # rubocop:enable Layout/LineLength

  monetize :amount_subunit, as: :amount, allow_nil: true

  belongs_to :user
  belongs_to :group
  # rubocop:disable Rails/InverseOf
  belongs_to :authorization_hold,
             class_name: 'Accounting::UserAuthorizationHold',
             foreign_key: :authorization_hold_uuid,
             optional: true
  # rubocop:enable Rails/InverseOf

  validate :content_matches_json_schema
  validate :content_all_items_reachable_in_menu
  validate :content_all_item_customizations_avaliable_for_item
  validate :content_all_item_customization_options_avaliable_on_customization
  validate :content_all_item_customization_options_count_in_permitted_range
  validate :content_all_item_customization_option_quantity_in_permitted_range

  before_validation :fill_in_calculated_data

  private

  def content_matches_json_schema
    JSON::Validator.fully_validate(MenuOrderSchema.schema, content).each do |error|
      error_without_schema_uuid = error.gsub(
        /schema [0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/,
        'schema'
      )
      errors.add(:content, error_without_schema_uuid)
    end
  end

  def content_all_items_reachable_in_menu
    return unless content.is_a? Hash

    selected_items = content['items']
    return unless selected_items.is_a? Array

    selected_item_uuids = selected_items.filter { |i| i.is_a? Hash }
                                        .map { |i| i['uuid'] }
                                        .compact

    reachable_menu_items = group&.avaliable_menu_items

    unreachable_item_uuids = selected_item_uuids - reachable_menu_items.keys
    return if unreachable_item_uuids.empty?

    unreachable_item_names =
      unreachable_item_uuids.map { |uuid| group.menu.is_a?(Hash) && group.menu.dig('items', uuid) }
                            .filter { |i| i.is_a? Hash }
                            .map { |i| i['name'] }

    errors.add(
      :content,
      :items_not_avaliable,
      unavaliable_item_uuids: unreachable_item_uuids,
      unavaliable_item_names: unreachable_item_names
    )
  end

  def content_all_item_customizations_avaliable_for_item
    return unless content.is_a? Hash

    selected_items = content['items']
    return unless selected_items.is_a? Array

    menu = group&.menu
    return unless menu.is_a? Hash

    menu_items = menu['items']
    return unless menu_items.is_a? Hash

    selected_items.each do |selected_item|
      item_uuid = selected_item['uuid']
      next unless item_uuid.is_a? String

      item_customizations = selected_item['customizations']
      next unless item_customizations.is_a? Hash

      item_customization_uuids = item_customizations.keys

      menu_item = menu_items[item_uuid]
      next unless menu_item.is_a? Hash

      menu_item_customization_uuids = menu_item['customizationUuids'] || []
      unavaliable_customization_uuids = item_customization_uuids - menu_item_customization_uuids
      next if unavaliable_customization_uuids.empty?

      unavaliable_customization_names =
        unavaliable_customization_uuids.map { |uuid| menu.dig('customizations', uuid, 'name') }
                                       .compact

      errors.add(
        :content,
        :customization_not_avaliable_on_item,
        item_uuid: item_uuid,
        item_name: menu_item['name'],
        unavaliable_customization_uuids: unavaliable_customization_uuids,
        unavaliable_customization_names: unavaliable_customization_names
      )
    end
  end

  # TODO: Try to refactor this
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def content_all_item_customization_options_avaliable_on_customization
    return unless content.is_a? Hash

    selected_items = content['items']
    return unless selected_items.is_a? Array

    menu = group&.menu
    return unless menu.is_a? Hash

    menu_items = menu['items']
    return unless menu_items.is_a? Hash

    selected_items.each do |selected_item|
      item_uuid = selected_item['uuid']
      next unless item_uuid.is_a? String

      item_customizations = selected_item['customizations']
      next unless item_customizations.is_a? Hash

      item_customizations.each do |item_customization_uuid, item_customization|
        item_customization_options = item_customization['options']
        next unless item_customization_options.is_a? Hash

        item_customization_option_uuids = item_customization_options.keys

        menu_customization = menu.dig('customizations', item_customization_uuid)
        next unless menu_customization.is_a? Hash

        menu_customization_option_uuids = menu_customization['optionUuids'] || []
        unavaliable_customization_option_uuids = item_customization_option_uuids - menu_customization_option_uuids
        next if unavaliable_customization_option_uuids.empty?

        unavaliable_customization_option_names =
          unavaliable_customization_option_uuids.map { |uuid| menu.dig('customizationOptions', uuid, 'name') }
                                                .compact

        errors.add(
          :content,
          :customization_option_not_avaliable_on_customization,
          item_uuid: item_uuid,
          item_name: menu.dig('items', item_uuid, 'name'),
          customization_uuid: item_customization_uuid,
          customization_name: menu_customization['name'],
          unavaliable_option_uuids: unavaliable_customization_option_uuids,
          unavaliable_option_names: unavaliable_customization_option_names
        )
      end
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength

  # TODO: Try to refactor this
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def content_all_item_customization_options_count_in_permitted_range
    return unless content.is_a? Hash

    selected_items = content['items']
    return unless selected_items.is_a? Array

    menu = group&.menu
    return unless menu.is_a? Hash

    menu_items = menu['items']
    return unless menu_items.is_a? Hash

    selected_items.each do |selected_item|
      item_uuid = selected_item['uuid']
      next unless item_uuid.is_a? String

      item_customizations = selected_item['customizations']
      item_customizations = {} unless item_customizations.is_a? Hash

      menu_item = menu_items[item_uuid]
      next unless menu_item.is_a? Hash

      menu_item_customization_uuids = menu_item['customizationUuids'] || []
      required_customizations = Hash[
        menu_item_customization_uuids.map { |uuid| [uuid, menu.dig('customizations', uuid)] }
                                     .filter { |_, c| c.is_a? Hash }
                                     .filter { |_, c| (c['minPermitted'] || 0).positive? }
      ]

      required_customizations.each do |menu_customization_uuid, menu_customization|
        item_customization = item_customizations[menu_customization_uuid] || {}
        item_customization_options = item_customization['options'] || {}
        selected_options_count = item_customization_options.map { |_, o| o['quantity'] }
                                                           .filter { |n| n.is_a? Integer }
                                                           .sum

        min_permitted_options_count = menu_customization['minPermitted'] || 0
        next unless selected_options_count < min_permitted_options_count

        errors.add(
          :content,
          :customization_options_count_less_then_min_permitted,
          item_uuid: item_uuid,
          item_name: menu.dig('items', item_uuid, 'name'),
          customization_uuid: menu_customization_uuid,
          customization_name: menu_customization['name'],
          min_permitted_options_count: min_permitted_options_count,
          selected_options_count: selected_options_count
        )
      end

      item_customizations.each do |item_customization_uuid, item_customization|
        menu_customization = menu.dig('customizations', item_customization_uuid)
        next unless menu_customization.is_a? Hash

        item_customization_options = item_customization['options']
        next unless item_customization_options.is_a? Hash

        selected_options_count = item_customization_options.map { |_, o| o['quantity'] }
                                                           .filter { |n| n.is_a? Integer }
                                                           .sum

        max_permitted_options_count = menu_customization['maxPermitted'] || Float::INFINITY
        next unless selected_options_count > max_permitted_options_count

        errors.add(
          :content,
          :customization_options_count_more_then_max_permitted,
          item_uuid: item_uuid,
          item_name: menu.dig('items', item_uuid, 'name'),
          customization_uuid: item_customization_uuid,
          customization_name: menu_customization['name'],
          max_permitted_options_count: max_permitted_options_count,
          selected_options_count: selected_options_count
        )
      end
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  # TODO: Try to refactor this
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  # rubocop:disable Metrics/BlockLength
  def content_all_item_customization_option_quantity_in_permitted_range
    return unless content.is_a? Hash

    selected_items = content['items']
    return unless selected_items.is_a? Array

    menu = group&.menu
    return unless menu.is_a? Hash

    menu_items = menu['items']
    return unless menu_items.is_a? Hash

    selected_items.each do |selected_item|
      item_uuid = selected_item['uuid']
      next unless item_uuid.is_a? String

      item_customizations = selected_item['customizations']
      item_customizations = {} unless item_customizations.is_a? Hash

      menu_item = menu_items[item_uuid]
      next unless menu_item.is_a? Hash

      menu_item_customization_uuids = menu_item['customizationUuids'] || []

      # rubocop:disable Style/HashTransformValues
      customizations_with_required_options = Hash[
        menu_item_customization_uuids.map { |uuid| [uuid, menu.dig('customizations', uuid)] }
                                     .filter { |_, c| c.is_a? Hash }
                                     .map do |uuid, c|
                                       [
                                         uuid,
                                         # Insert requiredOptions into customization
                                         c.merge(
                                           {
                                             required_options: Hash[
                                               (c['optionUuids'] || [])
                                                 .map { |o_uuid| [o_uuid, menu.dig('customizationOptions', o_uuid)] }
                                                 .filter { |_, o| o.is_a?(Hash) && (o['minPermitted'] || 0).positive? }
                                             ]
                                           }
                                         )
                                       ]
                                     end
      ]
      # rubocop:enable Style/HashTransformValues

      required_customizations_with_options =
        customizations_with_required_options.filter { |_, c| c[:required_options]&.any? }

      required_customizations_with_options.each do |customization_uuid, menu_customization|
        item_customization = item_customizations[customization_uuid] || {}
        item_customization_options = item_customization['options'] || {}

        (menu_customization[:required_options] || {}).each do |option_uuid, menu_option|
          min_permitted_quantity = menu_option['minPermitted'] || 0
          selected_quantity = item_customization_options.dig(option_uuid, 'quantity') || 0
          next if selected_quantity >= min_permitted_quantity

          errors.add(
            :content,
            :customization_option_quantity_less_then_min_permitted,
            item_uuid: item_uuid,
            item_name: menu_item['name'],
            customization_uuid: customization_uuid,
            customization_name: menu_customization['name'],
            option_uuid: option_uuid,
            option_name: menu_option['name'],
            min_permitted_quantity: min_permitted_quantity,
            selected_quantity: selected_quantity
          )
        end
      end

      item_customizations.each do |customization_uuid, item_customization|
        menu_customization = menu.dig('customizations', customization_uuid)
        next unless menu_customization.is_a? Hash

        item_customization_options = item_customization['options']
        next unless item_customization_options.is_a? Hash

        item_customization_options.each do |option_uuid, item_option|
          max_permitted_quantity = menu.dig('customizationOptions', option_uuid, 'maxPermitted') || Float::INFINITY
          selected_quantity = item_option['quantity'] || 0
          next if selected_quantity <= max_permitted_quantity

          errors.add(
            :content,
            :customization_option_quantity_more_then_max_permitted,
            item_uuid: item_uuid,
            item_name: menu_item['name'],
            customization_uuid: customization_uuid,
            customization_name: menu_customization['name'],
            option_uuid: option_uuid,
            option_name: menu.dig('customizationOptions', option_uuid, 'name'),
            max_permitted_quantity: max_permitted_quantity,
            selected_quantity: selected_quantity
          )
        end
      end
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/BlockLength

  def fill_in_calculated_data
    fill_in_calculated_data_in_content
    fill_in_amount_subunit
  end

  # TODO: Try to refactor this
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/BlockNesting
  def fill_in_calculated_data_in_content
    menu = group&.menu
    return unless menu.is_a? Hash

    return unless content.is_a? Hash

    items = content['items']
    return unless items.is_a? Array

    content['items'] = items.map do |item|
      if item.is_a? Hash
        item_name = menu.dig('items', item['uuid'], 'name')
        item_price_subunits = menu.dig('items', item['uuid'], 'priceSubunits')
        item = item.merge({ 'name' => item_name, 'priceSubunits' => item_price_subunits })

        customizations = item['customizations']
        if customizations.is_a? Hash
          customizations = Hash[
            customizations.map do |customization_uuid, customization|
              next unless customization.is_a? Hash

              customization_name = menu.dig('customizations', customization_uuid, 'name')
              customization = customization.merge({ 'name' => customization_name })

              options = customization['options']
              if options.is_a? Hash
                options = Hash[
                  options.map do |option_uuid, option|
                    next unless option.is_a? Hash

                    option_name = menu.dig('customizationOptions', option_uuid, 'name')
                    option = option.merge({ 'name' => option_name })

                    option_price_subunits = menu.dig('customizationOptions', option_uuid, 'priceSubunits')
                    option = if option_price_subunits.present?
                               option.merge({ 'priceSubunits' => option_price_subunits })
                             else
                               option.except('priceSubunits')
                             end

                    [option_uuid, option]
                  end
                ]
                customization = customization.merge({ 'options' => options })
              end

              [customization_uuid, customization]
            end
          ]
          item = item.merge({ 'customizations' => customizations })
        end
      end

      item
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/BlockNesting

  # TODO: Try to refactor this
  # rubocop:disable Metrics/AbcSize
  def fill_in_amount_subunit
    return unless content.is_a? Hash

    items = content['items']
    return unless items.is_a? Array

    item_amounts = items.map do |item|
      item_amount = 0

      if item.is_a? Hash
        item_amount += item['priceSubunits'] if item['priceSubunits'].is_a? Integer

        if item['customizations'].is_a? Hash
          item['customizations'].each_value do |customization|
            next unless customization['options'].is_a? Hash

            customization['options'].each_value do |option|
              next unless option['priceSubunits'].is_a? Integer
              next unless option['quantity'].is_a? Integer

              item_amount += option['priceSubunits'] * option['quantity']
            end
          end
        end

        item_amount *= item['quantity']
      end

      item_amount
    end

    self.amount = Money.new(item_amounts.sum)
  end
  # rubocop:enable Metrics/AbcSize
end
# rubocop:enable Metrics/ClassLength
