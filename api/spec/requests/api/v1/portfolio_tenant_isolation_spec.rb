# frozen_string_literal: true

require 'rails_helper'

# A candidate's portfolio is the most sensitive record this product holds: it
# carries their name, their interview transcript, and an AI judgement of their
# competence. Under UU PDP that is personal data an assessor from another
# organization has no lawful basis to see, and no candidate consented to.
#
# Assessment, Session and Vacancy include TenantScoped. Portfolio,
# PortfolioSkill, CoverageMap, TranscriptTurn, FitGapReport and
# AssessorOverride do not — they have no tenant_id column at all and are
# reachable only through associations. Every route that addresses them by :id
# therefore looks them up unscoped.
RSpec.describe 'Portfolio tenant isolation', type: :request do
  let(:org_a) { create(:organization, scheme: 'org-a') }
  let(:org_b) { create(:organization, scheme: 'org-b') }

  # A completed portfolio belonging to a candidate assessed by org B.
  let(:assessment_b) { create(:assessment, tenant_id: org_b.id) }
  let(:session_b)    { create(:session, :ended, assessment: assessment_b, tenant_id: org_b.id) }
  let(:portfolio_b)  { create(:portfolio, session: session_b) }
  let(:skill_b)      { create(:portfolio_skill, portfolio: portfolio_b, ai_level: 2) }

  describe 'GET /api/v1/portfolios/:id/export' do
    it "refuses to export another organization's portfolio" do
      get "/api/v1/portfolios/#{portfolio_b.id}/export?format=json",
          headers: auth_headers_for(org_a)

      expect(response).to have_http_status(:not_found)
    end

    it 'still exports a portfolio belonging to the requesting organization' do
      get "/api/v1/portfolios/#{portfolio_b.id}/export?format=json",
          headers: auth_headers_for(org_b)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /api/v1/portfolio_skills/:id/override' do
    # This one is worse than a read. set_portfolio_skill reads as if it were
    # scoped — PortfolioSkill.joins(:portfolio).find(...) — but the join adds
    # no filter, because Portfolio carries no tenant. An assessor at another
    # company can rewrite the level a candidate was given.
    it "refuses to override a skill on another organization's portfolio" do
      post "/api/v1/portfolio_skills/#{skill_b.id}/override",
           params: { override: { override_level: 5, assessor_notes: 'not mine to judge' } },
           headers: auth_headers_for(org_a),
           as: :json

      expect(response).to have_http_status(:not_found)
      expect(skill_b.reload.assessor_override).to be_nil
    end

    it 'still allows an override from the owning organization' do
      post "/api/v1/portfolio_skills/#{skill_b.id}/override",
           params: { override: { override_level: 4, assessor_notes: 'underrated' } },
           headers: auth_headers_for(org_b),
           as: :json

      expect(response).to have_http_status(:created)
      expect(skill_b.reload.assessor_override.override_level).to eq(4)
    end
  end

  describe 'POST /api/v1/portfolios/:id/fitgap' do
    let(:vacancy_a) { create(:vacancy, tenant_id: org_a.id) }

    it "refuses to score another organization's candidate against your vacancy" do
      post "/api/v1/portfolios/#{portfolio_b.id}/fitgap",
           params: { vacancy_id: vacancy_a.id },
           headers: auth_headers_for(org_a),
           as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
