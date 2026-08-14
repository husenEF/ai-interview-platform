# frozen_string_literal: true

# public.organizations is owned by rakamin-api, not by this service, so no
# migration here creates it and it is absent from db/schema.rb. db/seeds.rb
# conjures it with raw `CREATE TABLE IF NOT EXISTS` for development.
#
# The test database needs the same treatment: `maintain_test_schema!` loads
# db/schema.rb, which knows nothing about it, so without this every spec that
# resolves a tenant would fail on a missing relation.
#
# The DDL is deliberately a mirror of db/seeds.rb rather than a shared
# constant — duplicating eight columns is cheaper than giving this service a
# code path that looks like it owns another service's table.
RSpec.configure do |config|
  config.before(:suite) do
    ActiveRecord::Base.connection.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS public.organizations (
        id          BIGSERIAL PRIMARY KEY,
        name        VARCHAR(255) NOT NULL,
        scheme      VARCHAR(255) NOT NULL,
        identifier  VARCHAR(255) NOT NULL,
        host        VARCHAR(255) NOT NULL,
        alias_hosts VARCHAR[] NOT NULL DEFAULT '{}',
        config      JSONB NOT NULL DEFAULT '{}',
        created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    SQL
  end
end
