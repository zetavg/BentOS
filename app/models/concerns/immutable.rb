# frozen_string_literal: true

module Immutable
  extend ActiveSupport::Concern

  included do
    # Set this to a truthy value to bypass the immutable protect.
    attr_accessor :_really_update
  end

  class_methods do
    def immutable(**args)
      validate(if: args[:if]) do |record|
        next if record._really_update

        attributes = args[:attributes] || args[:only]
        changed_attribute_names = []

        if attributes.present?
          attributes = Array(attributes)
          changed_attribute_names = attributes.map(&:to_sym).intersection(
            record.changed_attribute_names_to_save.map(&:to_sym)
          )
          next if changed_attribute_names.blank?
        else
          next unless record.changed?

          changed_attribute_names = record.changed_attribute_names_to_save.map(&:to_sym)
        end

        error_key = Immutable.get_immutable_argument_value(record, args[:error_key], :immutable)
        message = Immutable.get_immutable_argument_value(record, args[:message], 'is immutable')
        error_options = Immutable.get_immutable_argument_value(record, args[:error_options], {})

        record.errors.add(
          :base,
          error_key,
          {
            message: message,
            changed_attribute_names: changed_attribute_names
          }.merge(error_options)
        )
      end
    end
  end

  def self.get_immutable_argument_value(record, arg, default)
    if arg.is_a? Proc
      case arg.arity
      when 0
        arg = record.instance_exec(&arg)
      when 1
        arg = record.instance_eval(&arg)
      end
    end

    arg.presence || default
  end
end
