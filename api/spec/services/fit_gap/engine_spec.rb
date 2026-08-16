# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FitGap::Engine do
  let(:tenant_id) { 1 }
  let(:session)   { create(:session, tenant_id: tenant_id) }
  let(:portfolio) { create(:portfolio, session: session, tenant_id: tenant_id) }
  let(:vacancy)   { create(:vacancy, tenant_id: tenant_id) }

  subject(:comparisons) do
    described_class.new(portfolio: portfolio, vacancy: vacancy).send(:build_skill_comparisons)
  end

  def comparison_for(label)
    comparisons.find { |c| c[:skill_label] == label }
  end

  describe 'a level the assessor set, not the AI' do
    # The comparison table renders a pencil marker for human-adjusted rows and
    # carries a legend saying so. The engine knew which rows were overridden --
    # effective_portfolio_skills computes `overridden` -- but dropped the flag
    # before it reached the payload, so the marker could never appear and an
    # assessor's own number was presented as machine output on a hiring
    # artifact.
    before do
      vacancy.vacancy_skills.create!(skill_label: 'Testing', expected_level: 4)
      skill = create(:portfolio_skill, portfolio: portfolio, skill_label: 'Testing',
                                       ai_level: 3, ai_confidence: 'medium')
      create(:assessor_override, portfolio_skill: skill, ai_level: 3, override_level: 4)
    end

    it 'marks the comparison as carrying a human override' do
      expect(comparison_for('Testing')[:is_override]).to be true
    end

    it 'compares against the overridden level' do
      expect(comparison_for('Testing')).to include(candidate_level: 4, result: 'match')
    end
  end

  describe 'a level the AI produced on its own' do
    before do
      vacancy.vacancy_skills.create!(skill_label: 'Debugging', expected_level: 3)
      create(:portfolio_skill, portfolio: portfolio, skill_label: 'Debugging',
                               ai_level: 3, ai_confidence: 'high')
    end

    it 'is not marked as overridden' do
      expect(comparison_for('Debugging')[:is_override]).to be false
    end
  end

  describe 'a skill with no rating' do
    before do
      vacancy.vacancy_skills.create!(skill_label: 'System Design', expected_level: 4)
      create(:portfolio_skill, portfolio: portfolio, skill_label: 'System Design',
                               ai_level: nil, ai_confidence: nil,
                               not_assessed_reason: 'never_probed')
    end

    it 'reports no candidate level rather than a gap' do
      expect(comparison_for('System Design'))
        .to include(candidate_level: nil, result: 'not_assessed', delta: nil)
    end

    it 'is not marked as overridden' do
      expect(comparison_for('System Design')[:is_override]).to be false
    end
  end
end
