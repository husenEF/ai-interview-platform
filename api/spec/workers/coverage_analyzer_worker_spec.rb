# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CoverageAnalyzerWorker do
  let(:session) { create(:session, :with_transcript, status: 'active') }
  let!(:map)    { create(:coverage_map, :never_probed, session: session, skill_label: 'Debugging') }

  before { allow(Sidekiq).to receive(:redis) }

  # The worker is retry: 0 and rescues everything, which is right — a coverage
  # analysis failure must not interrupt a live interview. What was wrong is that
  # it left no trace, so a skill the analyzer crashed on was indistinguishable
  # from a skill nobody asked about. The portfolio then told the recruiter the
  # candidate had not discussed it.
  context 'when the analyzer raises' do
    before do
      allow_any_instance_of(Coverage::Analyzer)
        .to receive(:call).and_raise(Gemini::HttpClient::ApiError, 'API returned 503')
    end

    it 'still does not interrupt the interview' do
      expect { described_class.new.perform(session.id, 3) }.not_to raise_error
    end

    it 'marks the coverage maps it could not update' do
      described_class.new.perform(session.id, 3)

      expect(map.reload.last_analysis_error).to include('API returned 503')
      expect(map.last_analysis_failed_at).to be_present
    end

    it 'makes the portfolio report the skill as unanalysed, not as never discussed' do
      described_class.new.perform(session.id, 3)

      session.update!(status: 'ended', ended_at: Time.current)
      stub_gemini_returning({ 'configured_skills' => [], 'discovered_skills' => [] })
      Portfolios::Generator.new(session: session.reload).call

      skill = session.portfolio.portfolio_skills.find_by(skill_label: 'Debugging')

      expect(skill.not_assessed_reason).to eq('analysis_failed')
      expect(skill.competency_summary).to include('does not mean the skill was not discussed')
    end
  end

  context 'when the session has already ended' do
    it 'does nothing' do
      session.update!(status: 'ended', ended_at: Time.current)

      expect_any_instance_of(Coverage::Analyzer).not_to receive(:call)
      described_class.new.perform(session.id, 3)
    end
  end

  context 'when the session no longer exists' do
    it 'does not mark anything' do
      expect { described_class.new.perform(-1, 3) }.not_to raise_error
      expect(map.reload.last_analysis_failed_at).to be_nil
    end
  end
end
