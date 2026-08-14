# frozen_string_literal: true

require 'database_cleaner/active_record'

RSpec.configure do |config|
  config.before(:suite) do
    # Truncate once up front so a crashed previous run cannot leak rows into
    # the first example of this one.
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before do
    DatabaseCleaner.strategy = :transaction
  end

  # Opt out with `:truncation` on any example that crosses a connection
  # boundary — Sidekiq inline execution, for instance, cannot see rows that
  # only exist inside another connection's open transaction.
  config.before(:each, :truncation) do
    DatabaseCleaner.strategy = :truncation
  end

  config.around do |example|
    DatabaseCleaner.cleaning { example.run }
  end
end
