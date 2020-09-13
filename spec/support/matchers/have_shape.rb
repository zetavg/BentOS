# frozen_string_literal: true

# Test if an Array or Hash matches the sample, ignoring extra keys or elements which are
# not in the sample, and also ignores the order of an array.
RSpec::Matchers.define :have_shape do |sample|
  match do |actual|
    @actual = actual
    @sample = sample

    have_shape?(@sample, @actual)
  end

  def have_shape?(sample, actual)
    case sample
    when Hash
      return false unless actual.is_a? Hash

      sample.each do |k, v|
        return false unless have_shape?(v, actual[k])
      end

    when Array
      return false unless actual.is_a? Array

      sample.each do |s|
        return false unless actual.any? { |a| have_shape?(s, a) }
      end

      true
    else
      sample == actual
    end
  end

  diffable

  # For diffable, filter out keys that are not in the samle and rearrange arrays
  def actual
    actual_as_sample(@sample, @actual)
  end

  def actual_as_sample(sample, actual)
    case sample
    when Hash
      return actual unless actual.is_a? Hash

      keys = sample.keys

      Hash[
        actual.select { |k| keys.include? k }
              .map { |k, v| [k, actual_as_sample(sample[k], v)] }
      ]
    when Array
      return actual unless actual.is_a? Array

      actual
        .sort_by { |e| sample.find_index { |se| have_shape?(se, e) } || Float::INFINITY }
        .each_with_index
        .map { |e, i| actual_as_sample(sample[i], e) }
    else
      actual
    end
  end
end
