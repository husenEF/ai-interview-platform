# frozen_string_literal: true

require 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('../config/environment', __dir__)

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'

# Support files hold the pieces that make this suite honest: no real network,
# a clean database per example, and an explicit tenant context (the app relies
# on RequestStore, which no test sets up for us).
Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort "#{e.to_s.strip}\n\nRun: make db-migrate"
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures')] if config.respond_to?(:fixture_paths=)
  config.use_transactional_fixtures = false # DatabaseCleaner owns this, see support/database_cleaner.rb
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
