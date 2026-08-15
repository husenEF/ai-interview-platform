# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Portfolios::Generator do
  subject(:generator) { described_class.new(session: session) }

  let(:assessment) { create(:assessment, tenant_id: 1) }
  let(:session)    { create(:session, :ended, :with_transcript, assessment: assessment) }

  before { create(:assessment_skill, assessment: assessment, skill_label: 'Debugging') }

  def gemini_payload(configured: [], discovered: [])
    { 'configured_skills' => configured, 'discovered_skills' => discovered }
  end

  def skill_payload(overrides = {})
    {
      'skill_id'           => 'SK-ENG-001',
      'skill_label'        => 'Debugging',
      'level'              => 3,
      'confidence'         => 'high',
      'evidence'           => ['I bisected the commit range before touching the code.'],
      'competency_summary' => 'Narrows the search space before changing anything.'
    }.merge(overrides)
  end

  # Without this, every "does not invent a rating" example below would also pass
  # against a generator that simply refused to store anything.
  describe 'a level the model did give' do
    it 'stores it as an assessed rating' do
      stub_gemini_returning(gemini_payload(configured: [skill_payload('level' => 4, 'confidence' => 'medium')]))

      generator.call
      skill = session.portfolio.portfolio_skills.sole

      expect(skill).to have_attributes(
        ai_level:            4,
        ai_confidence:       'medium',
        not_assessed_reason: nil,
        assessed?:           true
      )
    end
  end

  describe 'levels the model did not actually give' do
    # The candidate is the person harmed here: they never chose this product,
    # cannot see the rating, and a fabricated Level 1 is indistinguishable from
    # a real one to the recruiter reading the portfolio.
    [
      ['null',            nil,     'the model returned no level at all'],
      ['a non-numeric',   'abc',   'the model returned prose where a level belongs'],
      ['a missing key',   :absent, 'the model omitted the level key entirely'],
      ['a zero',          0,       'the model returned a level below the scale'],
      ['an out-of-range', 99,      'the model returned a level above the scale']
    ].each do |label, raw_level, why|
      it "does not invent a rating from #{label} level (#{why})" do
        payload = raw_level == :absent ? skill_payload.except('level') : skill_payload('level' => raw_level)
        stub_gemini_returning(gemini_payload(configured: [payload]))

        generator.call
        skill = session.portfolio.portfolio_skills.sole

        expect(skill.ai_level).to be_nil,
                                  "expected no rating, got Level #{skill.ai_level} manufactured from #{raw_level.inspect}"
        expect(skill.not_assessed_reason).to eq('insufficient_evidence')
        expect(skill.ai_confidence).to be_nil
      end
    end

    it 'accepts an integer-valued float, because JSON has one number type' do
      stub_gemini_returning(gemini_payload(configured: [skill_payload('level' => 3.0)]))

      generator.call

      expect(session.portfolio.portfolio_skills.sole.ai_level).to eq(3)
    end

    it 'keeps a real level when only the confidence is unusable' do
      stub_gemini_returning(gemini_payload(configured: [skill_payload('level' => 4, 'confidence' => 'extremely')]))

      generator.call
      skill = session.portfolio.portfolio_skills.sole

      expect(skill.ai_level).to eq(4)
      expect(skill.ai_confidence).to eq('low')
    end
  end

  describe 'skills the interview never reached' do
    it 'does not rate a skill whose coverage state is still not_yet' do
      create(:coverage_map, :never_probed, session: session, skill_label: 'Debugging')
      stub_gemini_returning(gemini_payload(configured: [skill_payload('level' => 2)]))

      generator.call
      skill = session.portfolio.portfolio_skills.find_by(skill_label: 'Debugging')

      expect(skill.ai_level).to be_nil,
                                "expected no rating for a never-probed skill, got Level #{skill.ai_level}"
      expect(skill.not_assessed_reason).to eq('never_probed')
    end

    it 'keeps an unprobed skill visible in the portfolio rather than dropping it' do
      create(:coverage_map, :never_probed, session: session, skill_label: 'Debugging')
      stub_gemini_returning(gemini_payload(configured: []))

      generator.call

      expect(session.portfolio.portfolio_skills.pluck(:skill_label)).to include('Debugging')
    end

    it 'does not ask the model to rate a skill it never probed' do
      create(:coverage_map, :never_probed, session: session, skill_label: 'Debugging')
      create(:coverage_map, session: session, skill_label: 'Testing', state: 'covered')
      stub_gemini_returning(gemini_payload(configured: []))

      generator.call

      expect(sent_prompt).to include('Testing')
      expect(sent_prompt).not_to include('Debugging')
    end
  end

  describe 'assessor overrides' do
    it 'survives regeneration of the portfolio' do
      stub_gemini_returning(gemini_payload(configured: [skill_payload]))
      portfolio = generator.call

      override = create(:assessor_override,
                        portfolio_skill: portfolio.portfolio_skills.sole,
                        override_level: 5)

      described_class.new(session: session.reload).call

      expect(AssessorOverride.exists?(override.id)).to be(true),
                                                       'regenerating the portfolio destroyed the assessor\'s manual override'
    end
  end

  describe 'when the model fails' do
    it 'records every skill as unassessed rather than leaving stale ratings in place' do
      stub_gemini_returning(gemini_payload(configured: [skill_payload('level' => 4)]))
      portfolio = generator.call
      create(:coverage_map, session: session, skill_label: 'Debugging', state: 'covered')

      stub_gemini_erroring(500)
      expect { described_class.new(session: session.reload).call }
        .to raise_error(Gemini::HttpClient::ApiError)

      skill = portfolio.reload.portfolio_skills.find_by(skill_label: 'Debugging')
      expect(skill).to have_attributes(ai_level: nil, not_assessed_reason: 'analysis_failed')
      expect(portfolio.generation_status).to eq('failed')
    end

    # Asserted against ApiError, the shared superclass, rather than TimeoutError:
    # WebMock's to_timeout simulates a *connect* timeout, which Faraday's net_http
    # adapter maps to ConnectionFailed, while the client's TimeoutError branch
    # catches Faraday::TimeoutError (a read timeout). Both reach the same
    # unassessed-recording path, which is what this example is about.
    it 'records unassessed skills when the request never completes' do
      create(:coverage_map, session: session, skill_label: 'Debugging', state: 'covered')
      stub_gemini_timing_out

      expect { generator.call }.to raise_error(Gemini::HttpClient::ApiError)

      expect(session.reload.portfolio.portfolio_skills.sole.not_assessed_reason).to eq('analysis_failed')
    end

    it 'leaves no half-written portfolio behind' do
      stub_gemini_returning(gemini_payload(configured: [skill_payload, skill_payload('skill_label' => nil)]))

      expect { generator.call }.to raise_error(ActiveRecord::RecordInvalid)

      expect(session.reload.portfolio.portfolio_skills.count).to eq(0),
                                                                 'a partially written portfolio was committed'
    end
  end

  describe 'regeneration' do
    it 'does not accumulate duplicate rows for the same skill' do
      stub_gemini_returning(gemini_payload(configured: [skill_payload]))

      generator.call
      described_class.new(session: session.reload).call

      expect(session.reload.portfolio.portfolio_skills.count).to eq(1)
    end

    it 'drops a skill the model no longer returns' do
      stub_gemini_returning(gemini_payload(configured: [skill_payload, skill_payload('skill_label' => 'Testing')]))
      generator.call

      stub_gemini_returning(gemini_payload(configured: [skill_payload]))
      described_class.new(session: session.reload).call

      expect(session.reload.portfolio.portfolio_skills.pluck(:skill_label)).to eq(['Debugging'])
    end
  end

  describe 'prompt construction' do
    it 'fences the transcript as untrusted, the way the coverage prompt does' do
      stub_gemini_returning(gemini_payload(configured: [skill_payload]))

      generator.call

      expect(sent_prompt).to include('BEGIN UNTRUSTED TRANSCRIPT'),
                             'candidate speech is injected into the scoring prompt unfenced'
      expect(sent_prompt).to include('END UNTRUSTED TRANSCRIPT')
    end
  end

  # The prompt is the product here — what the model is asked determines what the
  # candidate is rated on — so it is asserted against directly rather than
  # inferred from the response.
  def sent_prompt
    signature = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last
    JSON.parse(signature.body).dig('contents', 0, 'parts', 0, 'text')
  end
end
