# frozen_string_literal: true

class Portfolio < ApplicationRecord
  include TenantScoped

  GENERATION_STATUSES = %w[pending generating complete failed].freeze

  belongs_to :session
  has_many :portfolio_skills, dependent: :destroy
  has_many :assessor_overrides, through: :portfolio_skills

  validates :generation_status, inclusion: { in: GENERATION_STATUSES }

  scope :complete,    -> { where(generation_status: 'complete') }
  scope :failed,      -> { where(generation_status: 'failed') }
  scope :generating,  -> { where(generation_status: 'generating') }

  def complete?    = generation_status == 'complete'
  def generating?  = generation_status == 'generating'
  def failed?      = generation_status == 'failed'

  private

  # Overrides TenantScoped#assign_tenant_id rather than adding another
  # before_validation, so this does not depend on callback ordering.
  #
  # A portfolio's tenant is a fact about the session that produced it, not
  # ambient request context. Two reasons that matters:
  #
  #   - PortfolioGeneratorWorker creates portfolios from Sidekiq, where
  #     RequestStore is empty and Current.tenant_id raises.
  #   - Deferring to ambient context would let a request under one tenant
  #     create a candidate's portfolio under another.
  #
  # Session is read unscoped on purpose: Session is itself TenantScoped, so
  # `session.tenant_id` resolves under whatever tenant is ambient and returns
  # nil whenever that differs from the session's own.
  def assign_tenant_id
    # Assignment, not ||=. TenantScoped's default_scope is a where clause, and
    # Rails seeds those onto newly built records — so tenant_id already holds
    # the ambient tenant here and ||= would never fire. The session's tenant
    # has to overwrite it.
    #
    # Session is read unscoped because Session is itself TenantScoped: plain
    # `session.tenant_id` resolves under the ambient tenant and returns nil
    # whenever that differs from the session's own.
    owning_tenant_id = Session.unscoped.where(id: session_id).pick(:tenant_id)
    self.tenant_id = owning_tenant_id if owning_tenant_id

    super # falls back to Current.tenant_id when there is no session to inherit from
  end
end
