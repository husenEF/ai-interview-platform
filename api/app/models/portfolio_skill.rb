# frozen_string_literal: true

class PortfolioSkill < ApplicationRecord
  CONFIDENCE_LEVELS = %w[high medium low].freeze

  belongs_to :portfolio
  has_one :assessor_override, dependent: :destroy

  # Portfolio skills have no tenant_id of their own; they belong to whichever
  # organization owns the portfolio. merge(Portfolio.all) pulls in Portfolio's
  # TenantScoped default scope, so this filters by the current tenant rather
  # than merely joining — a plain joins(:portfolio) reads like a scope but
  # restricts nothing.
  scope :for_current_tenant, -> { joins(:portfolio).merge(Portfolio.all) }

  validates :skill_label, presence: true
  validates :ai_level, numericality: { only_integer: true, in: 1..5 }
  validates :ai_confidence, inclusion: { in: CONFIDENCE_LEVELS }
  validates :competency_summary, presence: true

  # evidence is stored as JSONB array of quote strings
  def evidence_quotes
    Array(evidence)
  end
end
