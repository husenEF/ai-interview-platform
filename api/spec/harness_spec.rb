# frozen_string_literal: true

require 'rails_helper'

# Guards the test harness itself. Everything else in this suite assumes these
# four things hold; when one silently stops holding, other specs fail in ways
# that look like product bugs.
RSpec.describe 'test harness' do
  it 'builds every factory without validation or constraint errors' do
    # FactoryBot.lint raises with the full list of broken factories, which is a
    # far better failure message than a NOT NULL violation surfacing three
    # specs later in an unrelated file.
    expect { FactoryBot.lint(FactoryBot.factories, traits: true) }.not_to raise_error
  end

  it 'resolves organizations to exactly one table, in the public schema' do
    expect(ActiveRecord::Base.connection.schema_search_path).to eq('ai_interview,public')

    # Organization.table_name is unqualified and relies on search_path order.
    # That is only safe while ai_interview holds no organizations table of its
    # own — which in turn relies on 20231201000000_create_organizations running
    # before 20240101000000_create_ai_interview_schema creates that schema.
    #
    # Anything that creates the ai_interview schema early (a hand-rolled
    # docker-compose init script, say) silently shadows public.organizations
    # with an empty copy, and every request 403s with "Tenant not found".
    # This guards that ordering.
    schemas = ActiveRecord::Base.connection.select_values(<<~SQL.squish)
      SELECT table_schema FROM information_schema.tables
      WHERE table_name = 'organizations'
    SQL

    expect(schemas).to eq(['public'])
    expect { Organization.count }.not_to raise_error
  end

  it 'refuses outbound HTTP so no spec can reach the real Gemini API' do
    expect { Faraday.get('https://generativelanguage.googleapis.com/health') }
      .to raise_error(WebMock::NetConnectNotAllowedError)
  end

  # Production sets config.eager_load = true, and test sets it to
  # ENV['CI'].present? — so on a developer machine every file is loaded lazily
  # and a name Zeitwerk cannot resolve is invisible until deploy.
  #
  # app/channels/audio_websocket_middleware.rb defined AudioWebSocketMiddleware,
  # while that path obliges it to define AudioWebsocketMiddleware. The whole
  # suite passed locally; the boot raised NameError in production and in CI.
  #
  # Eager loading here rather than trusting the environment flag, so the guard
  # holds wherever the suite runs.
  it 'eager loads, which is what production does before serving a request' do
    expect { Rails.application.eager_load! }.not_to raise_error
  end

  describe 'as_tenant' do
    it 'scopes TenantScoped models and restores the previous context' do
      mine   = create(:assessment, tenant_id: 1)
      theirs = create(:assessment, tenant_id: 2)

      as_tenant(1) do
        expect(Assessment.pluck(:id)).to eq([mine.id])
      end

      as_tenant(2) do
        expect(Assessment.pluck(:id)).to eq([theirs.id])
      end

      # Outside any tenant, TenantScoped currently degrades to `all`. This
      # assertion documents today's fail-open behaviour so that changing it is
      # a deliberate, visible act rather than an accident.
      expect(Assessment.count).to eq(2)
    end
  end
end
