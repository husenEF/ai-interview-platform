# frozen_string_literal: true

module Assessments
  # A rating is either a level on the 1..5 scale, or a stated reason there is no
  # level. There is no third state, and in particular there is no "level we made
  # up because the column was NOT NULL".
  #
  # Everything that turns model output into a stored rating goes through
  # .from_model_output. That is the point of the class: the coercion lives in one
  # named place that can be read, tested and reasoned about, instead of being
  # spelled `.to_i.clamp(1, 5)` at each call site — an expression that looks like
  # defensive input validation and in fact manufactures a Level 1 out of nil.
  class Rating
    SCALE   = (1..5).freeze
    REASONS = %i[never_probed insufficient_evidence analysis_failed].freeze

    CONFIDENCE_LEVELS = %w[high medium low].freeze

    class NotAssessedError < StandardError; end

    attr_reader :level, :confidence, :reason

    class << self
      def assessed(level, confidence:)
        new(level: level, confidence: confidence, reason: nil)
      end

      def unassessed(reason)
        new(level: nil, confidence: nil, reason: reason)
      end

      # Builds a rating from one skill entry of the model's JSON output.
      #
      # coverage_state is authoritative over the model: if the interview never
      # probed a skill there is nothing to rate, however confident the model
      # sounds about it. The model is asked to rate "EACH skill in the coverage
      # map" and has no way to decline, so it will always produce a number.
      def from_model_output(raw_level, raw_confidence, coverage_state: nil)
        return unassessed(:never_probed) if coverage_state.to_s == 'not_yet'

        level = coerce_level(raw_level)
        return unassessed(:insufficient_evidence) if level.nil?

        assessed(level, confidence: coerce_confidence(raw_confidence))
      end

      private

      # Deliberately strict, and deliberately not clamping. A level outside the
      # scale means the model did not answer the question that was asked, and
      # rounding 99 down to 5 or 0 up to 1 presents that as a judgement about
      # the candidate. Integer-valued floats are accepted because JSON has one
      # number type and some models emit 3.0.
      def coerce_level(raw)
        level =
          case raw
          when Integer then raw
          when Float   then (raw % 1).zero? ? raw.to_i : nil
          when String  then raw.match?(/\A\s*-?\d+\s*\z/) ? raw.to_i : nil
          end

        SCALE.cover?(level) ? level : nil
      end

      # An unrecognised confidence is not worth discarding a real level over,
      # but it must not be stored as if the model had said it.
      def coerce_confidence(raw)
        CONFIDENCE_LEVELS.include?(raw.to_s) ? raw.to_s : 'low'
      end
    end

    def initialize(level:, confidence:, reason:)
      @level      = level
      @confidence = confidence
      @reason     = reason
      freeze
    end

    def assessed? = !@level.nil?

    def level!
      raise NotAssessedError, "skill was not assessed (#{@reason})" unless assessed?

      @level
    end

    # Column values for portfolio_skills. Named for what it produces so the
    # generator does not have to know which of the three columns pair together —
    # that pairing is enforced by chk_portfolio_skills_rating_xor.
    def to_columns
      { ai_level: @level, ai_confidence: @confidence, not_assessed_reason: @reason&.to_s }
    end

    def ==(other)
      other.is_a?(Rating) && other.to_columns == to_columns
    end
    alias eql? ==

    def hash = to_columns.hash
  end
end
