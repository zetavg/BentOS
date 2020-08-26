# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, type: :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# Provides a way to simulate database failure, which we can use to test if our transactions are safe.
module DatabaseFailureSimulator
  @@countdown = 0 # rubocop:disable Style/ClassVars
  @@match_sql = '' # rubocop:disable Style/ClassVars

  mattr_accessor :countdown, :match_sql

  def self.failure_countdown(countdown = 1)
    self.countdown = countdown
  end

  def self.failure_on_next(match_sql)
    self.match_sql = match_sql
  end

  def self.reset
    self.countdown = 0
    self.match_sql = ''
  end

  def self.check_sql(sql)
    if countdown > 0
      self.countdown = countdown - 1

      if countdown <= 0
        error_message = "Boom! This is a simulated database failure. SQL: `#{sql}` hits countdown 0."
        self.countdown = 0
        raise SimulatedDatabaseError, error_message
      end
    end

    if match_sql.present? && sql.match(match_sql) # rubocop:disable Style/GuardClause
      error_message = "Boom! This is a simulated database failure. SQL: `#{sql}` matches `#{match_sql}`."
      self.match_sql = ''
      raise SimulatedDatabaseError, error_message
    end
  end

  class SimulatedDatabaseError < StandardError; end

  def execute(sql, *)
    DatabaseFailureSimulator.check_sql(sql)

    super
  end

  def exec_query(sql, *, **)
    DatabaseFailureSimulator.check_sql(sql)

    super
  end

  def exec_insert(sql, *, **)
    DatabaseFailureSimulator.check_sql(sql)

    super
  end

  def exec_update(sql, *, **)
    DatabaseFailureSimulator.check_sql(sql)

    super
  end

  def exec_delete(sql, *, **)
    DatabaseFailureSimulator.check_sql(sql)

    super
  end
end

::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend DatabaseFailureSimulator

# Tell DoubleEntry not to complain about a containing transaction (DoubleEntry::Locking::LockMustBeOutermostTransaction)
# when we call lock_accounts.
DoubleEntry::Locking.configuration.running_inside_transactional_fixtures = true
