# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Portfolio do
  let(:assessment) { create(:assessment, tenant_id: 7) }
  let(:session)    { create(:session, :ended, assessment: assessment, tenant_id: 7) }

  describe 'tenant assignment' do
    # PortfolioGeneratorWorker calls session.create_portfolio! from Sidekiq,
    # where RequestStore is empty. TenantScoped's assign_tenant_id reads
    # Current.tenant_id, which raises when unset, so without inheriting from
    # the session every generated portfolio would blow up.
    it 'inherits the tenant from its session when created outside a request' do
      expect(RequestStore.store).not_to have_key(:tenant_id)

      portfolio = session.create_portfolio!(candidate_id: session.candidate_id)

      expect(portfolio.tenant_id).to eq(7)
    end

    it 'still inherits from the session even when a different tenant is ambient' do
      # The session is the authority on who a portfolio belongs to. Ambient
      # request context must not be able to reassign a candidate's record to
      # another organization.
      portfolio = as_tenant(999) do
        session.create_portfolio!(candidate_id: session.candidate_id)
      end

      expect(portfolio.tenant_id).to eq(7)
    end
  end

  describe 'scoping' do
    it 'hides portfolios belonging to other tenants' do
      mine = create(:portfolio, session: session)

      other_session = create(:session, :ended,
                             assessment: create(:assessment, tenant_id: 8),
                             tenant_id: 8)
      create(:portfolio, session: other_session)

      as_tenant(7) do
        expect(described_class.pluck(:id)).to eq([mine.id])
      end
    end

    it 'scopes portfolio skills through their portfolio' do
      mine  = create(:portfolio_skill, portfolio: create(:portfolio, session: session))
      other = create(:portfolio_skill,
                     portfolio: create(:portfolio,
                                       session: create(:session, :ended,
                                                       assessment: create(:assessment, tenant_id: 8),
                                                       tenant_id: 8)))

      as_tenant(7) do
        ids = PortfolioSkill.for_current_tenant.pluck(:id)
        expect(ids).to include(mine.id)
        expect(ids).not_to include(other.id)
      end
    end
  end
end
