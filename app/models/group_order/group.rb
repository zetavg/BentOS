# frozen_string_literal: true

require Rails.root.join('lib', 'schemas', 'menu_schema')

class GroupOrder::Group < ApplicationRecord
  include AASM

  monetize :group_minimum_amount_subunit, as: :group_minimum_amount
  monetize :group_maximum_amount_subunit, as: :group_maximum_amount, allow_nil: true

  aasm column: :state, create_scopes: false, whiny_persistence: true do
    state :open, initial: true
    state :locked
  end

  belongs_to :organizer, class_name: 'User', inverse_of: :organized_groups

  validates :name, presence: true
  validates :to_be_closed_at, :expected_delivery_time, presence: true
  validates :group_minimum_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: false
  validates :group_minimum_sets, numericality: { greater_than_or_equal_to: 0 }, allow_nil: false
  validates :group_maximum_amount, numericality: { greater_than: 0 }, allow_nil: true
  validates :group_maximum_sets, numericality: { greater_than: 0 }, allow_nil: true

  validate :menu_matches_json_schema
  validate :menu_all_section_uuids_exists
  validate :menu_all_item_uuids_exists
  validate :menu_all_customization_uuids_exists
  validate :menu_all_customization_option_uuids_exists
  validate :menu_all_customization_option_min_permitted_not_conflict_with_max_permitted

  def avaliable_menu_items
    section_uuids = menu.dig('menu', 'sectionUuids')
    return {} unless section_uuids.is_a? Array

    section_uuids
      .map { |section_id| menu.dig('sections', section_id) }
      .compact
      .map { |section| section['itemUuids'] }
      .flatten
      .uniq
      .index_with { |item_id| menu.dig('items', item_id) }
  end

  def account
    DoubleEntry.account(:group_account, scope: self)
  end

  private

  def menu_matches_json_schema
    JSON::Validator.fully_validate(MenuSchema.schema, menu).each do |error|
      error_without_schema_uuid = error.gsub(
        /schema [0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/,
        'schema'
      )
      errors.add(:menu, error_without_schema_uuid)
    end
  end

  def menu_all_section_uuids_exists
    return unless menu.is_a? Hash

    section_uuids = menu.dig('menu', 'sectionUuids')
    return unless section_uuids.is_a? Array

    sections = menu['sections']
    return unless sections.is_a? Hash

    missing_section_uuids = section_uuids.map(&:to_s) - sections.keys.map(&:to_s)
    return if missing_section_uuids.length <= 0

    errors.add(:menu, :sections_missing, missing_section_uuids: missing_section_uuids)
  end

  def menu_all_item_uuids_exists
    return unless menu.is_a? Hash

    sections = menu['sections']
    return unless sections.is_a? Hash

    items = menu['items']
    return unless items.is_a? Hash

    item_uuids = sections.values.map { |s| s['itemUuids'] }.flatten.uniq.compact

    missing_item_uuids = item_uuids.map(&:to_s) - items.keys.map(&:to_s)
    return if missing_item_uuids.length <= 0

    errors.add(:menu, :items_missing, missing_item_uuids: missing_item_uuids)
  end

  def menu_all_customization_uuids_exists
    return unless menu.is_a? Hash

    items = menu['items']
    return unless items.is_a? Hash

    customizations = menu['customizations'] || {}

    customization_uuids = items.values.map { |i| i['customizationUuids'] }.flatten.uniq.compact

    missing_customization_uuids = customization_uuids.map(&:to_s) - customizations.keys.map(&:to_s)
    return if missing_customization_uuids.length <= 0

    errors.add(:menu, :customizations_missing, missing_customization_uuids: missing_customization_uuids)
  end

  def menu_all_customization_option_uuids_exists
    return unless menu.is_a? Hash

    customizations = menu['customizations']
    return unless customizations.is_a? Hash

    customization_options = menu['customizationOptions'] || {}

    option_uuids = customizations.values.map { |i| i['optionUuids'] }.flatten.uniq.compact

    missing_customization_option_uuids = option_uuids.map(&:to_s) - customization_options.keys.map(&:to_s)
    return if missing_customization_option_uuids.length <= 0

    errors.add(
      :menu,
      :customization_options_missing,
      missing_customization_option_uuids: missing_customization_option_uuids
    )
  end

  def menu_all_customization_option_min_permitted_not_conflict_with_max_permitted
    return unless menu.is_a? Hash

    customizations = menu['customizations']
    return unless customizations.is_a? Hash

    conflict_customization_uuids = []

    customizations.each do |uuid, customization|
      next unless customization.is_a? Hash
      next unless customization['maxPermitted'].is_a? Integer

      option_uuids = customization['optionUuids'] || []
      min_permitted_options_count =
        option_uuids.map { |o_uuid| menu.dig('customizationOptions', o_uuid) }
                    .filter { |o| o.is_a? Hash }
                    .map { |o| o['minPermitted'] }
                    .compact
                    .sum

      next unless min_permitted_options_count > customization['maxPermitted']

      conflict_customization_uuids.push uuid
    end

    return if conflict_customization_uuids.empty?

    errors.add(
      :menu,
      :customization_option_min_permitted_conflicts_with_customization_max_permitted,
      customization_uuids: conflict_customization_uuids
    )
  end
end
