# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Assessments::Rating do
  describe '.from_model_output' do
    context 'with a usable level' do
      it 'keeps integers on the scale' do
        (1..5).each do |level|
          rating = described_class.from_model_output(level, 'high', coverage_state: 'covered')
          expect(rating).to have_attributes(assessed?: true, level: level, confidence: 'high')
        end
      end

      it 'accepts an integer-valued float' do
        expect(described_class.from_model_output(3.0, 'high').level).to eq(3)
      end

      it 'accepts a numeric string' do
        expect(described_class.from_model_output('3', 'high').level).to eq(3)
      end

      it 'falls back to low confidence rather than storing an unrecognised value' do
        expect(described_class.from_model_output(3, 'quite sure').confidence).to eq('low')
      end
    end

    context 'with a level the model did not really give' do
      # Each of these produced Level 1 under `.to_i.clamp(1, 5)` — the lowest
      # rating on the scale, indistinguishable in the portfolio from a rating
      # the model actually argued for.
      [nil, 'abc', '', 0, -1, 99, 2.5, [], {}].each do |raw|
        it "refuses to invent a level from #{raw.inspect}" do
          rating = described_class.from_model_output(raw, 'high')

          expect(rating).to have_attributes(
            assessed?:  false,
            level:      nil,
            confidence: nil,
            reason:     :insufficient_evidence
          )
        end
      end
    end

    context 'when the skill was never probed' do
      it 'ignores the level the model produced anyway' do
        rating = described_class.from_model_output(4, 'high', coverage_state: 'not_yet')

        expect(rating).to have_attributes(assessed?: false, reason: :never_probed)
      end
    end
  end

  describe '#level!' do
    it 'returns the level when assessed' do
      expect(described_class.assessed(3, confidence: 'high').level!).to eq(3)
    end

    # Callers that need a number must handle the absence explicitly rather than
    # receive a nil that quietly becomes 0 further downstream.
    it 'raises rather than returning a stand-in when unassessed' do
      expect { described_class.unassessed(:never_probed).level! }
        .to raise_error(described_class::NotAssessedError, /never_probed/)
    end
  end

  describe '#to_columns' do
    it 'pairs the columns the way the XOR constraint requires' do
      expect(described_class.assessed(3, confidence: 'high').to_columns)
        .to eq(ai_level: 3, ai_confidence: 'high', not_assessed_reason: nil)

      expect(described_class.unassessed(:analysis_failed).to_columns)
        .to eq(ai_level: nil, ai_confidence: nil, not_assessed_reason: 'analysis_failed')
    end
  end

  it 'is immutable' do
    expect(described_class.assessed(3, confidence: 'high')).to be_frozen
  end
end
