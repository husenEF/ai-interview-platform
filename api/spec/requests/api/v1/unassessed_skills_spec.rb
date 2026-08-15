# frozen_string_literal: true

require 'rails_helper'

# The whole point of making "not assessed" representable is that it reaches the
# people who act on it. A reason stored in the database and dropped at the API
# boundary changes nothing for the recruiter reading the portfolio.
RSpec.describe 'Unassessed skills', type: :request do
  let(:org)        { create(:organization) }
  let(:assessment) { create(:assessment, tenant_id: org.id) }
  let(:session)    { create(:session, :ended, assessment: assessment, tenant_id: org.id) }
  let(:portfolio)  { create(:portfolio, session: session) }

  describe 'GET /api/v1/sessions/:id/portfolio' do
    it 'reports the reason a skill has no level' do
      create(:portfolio_skill, :not_assessed, portfolio: portfolio,
                               skill_label: 'Debugging', not_assessed_reason: 'analysis_failed')

      get "/api/v1/sessions/#{session.id}/portfolio", headers: auth_headers_for(org)

      skill = json_body.dig('portfolio', 'skills').find { |s| s['skill_label'] == 'Debugging' }
      expect(skill).to include('ai_level' => nil, 'not_assessed_reason' => 'analysis_failed')
    end

    it 'still reports a level for an assessed skill' do
      create(:portfolio_skill, portfolio: portfolio, skill_label: 'Testing', ai_level: 4)

      get "/api/v1/sessions/#{session.id}/portfolio", headers: auth_headers_for(org)

      skill = json_body.dig('portfolio', 'skills').find { |s| s['skill_label'] == 'Testing' }
      expect(skill).to include('ai_level' => 4, 'not_assessed_reason' => nil)
    end
  end

  describe 'POST /api/v1/portfolio_skills/:id/override' do
    # An assessor supplying the judgement the model could not is the intended
    # recovery path, not an edge case. Blocking it would have made "not
    # assessed" a dead end for the candidate.
    it 'lets an assessor rate a skill the model could not' do
      skill = create(:portfolio_skill, :not_assessed, portfolio: portfolio)

      post "/api/v1/portfolio_skills/#{skill.id}/override",
           params: { override: { override_level: 4, assessor_notes: 'Covered this at length in the panel round.' } },
           headers: auth_headers_for(org)

      expect(response).to have_http_status(:created)
      expect(json_body['override']).to include('ai_level' => nil, 'override_level' => 4)
    end
  end
end
