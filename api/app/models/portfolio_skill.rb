# frozen_string_literal: true

class PortfolioSkill < ApplicationRecord
  CONFIDENCE_LEVELS   = %w[high medium low].freeze
  NOT_ASSESSED_REASONS = %w[never_probed insufficient_evidence analysis_failed].freeze

  belongs_to :portfolio
  has_one :assessor_override, dependent: :destroy

  # Portfolio skills have no tenant_id of their own; they belong to whichever
  # organization owns the portfolio. merge(Portfolio.all) pulls in Portfolio's
  # TenantScoped default scope, so this filters by the current tenant rather
  # than merely joining — a plain joins(:portfolio) reads like a scope but
  # restricts nothing.
  scope :for_current_tenant, -> { joins(:portfolio).merge(Portfolio.all) }

  validates :skill_label, presence: true
  validates :competency_summary, presence: true

  # A skill is either assessed or explicitly not assessed — never both, never
  # neither. chk_portfolio_skills_rating_xor enforces this in the database;
  # these validations are here so the failure is a readable error rather than
  # a StatementInvalid, not as the primary guard.
  with_options if: :assessed? do
    validates :ai_level, numericality: { only_integer: true, in: 1..5 }
    validates :ai_confidence, inclusion: { in: CONFIDENCE_LEVELS }
    validates :not_assessed_reason, absence: true
  end

  with_options unless: :assessed? do
    validates :not_assessed_reason, inclusion: { in: NOT_ASSESSED_REASONS }
    validates :ai_confidence, absence: true
  end

  def assessed? = ai_level.present?

  def rating
    return Assessments::Rating.unassessed(not_assessed_reason.to_sym) unless assessed?

    Assessments::Rating.assessed(ai_level, confidence: ai_confidence)
  end

  # evidence is stored as JSONB array of quote strings
  def evidence_quotes
    Array(evidence)
  end
end
