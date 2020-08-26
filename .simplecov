# frozen_string_literal: true

require 'coveralls'

# SimpleCov.start 'rails'
# We only calculate test coverage on model layer for now.
# See: https://github.com/simplecov-ruby/simplecov/blob/main/lib/simplecov/profiles/rails.rb
SimpleCov.start do
  load_profile 'test_frameworks'

  add_filter %r{^/config/}
  add_filter %r{^/db/}

  add_filter 'app/controllers'
  add_filter 'app/channels'
  add_filter 'app/mailers'
  add_filter 'app/helpers'
  add_filter %w[app/jobs app/workers]

  add_group 'Models', 'app/models'
  add_group 'Libraries', 'lib/'

  track_files '{app,lib}/**/*.rb'
end

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
  [
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
  ]
)
