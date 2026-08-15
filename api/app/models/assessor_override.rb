# frozen_string_literal: true

class AssessorOverride < ApplicationRecord
  belongs_to :portfolio_skill

  # ai_level is a snapshot of what the AI said when the assessor disagreed. It
  # is absent when the AI produced no rating at all — the case where an
  # assessor's own judgement matters most.
  validates :ai_level, numericality: { only_integer: true, in: 1..5 }, allow_nil: true
  validates :override_level, numericality: { only_integer: true, in: 1..5 }
  validates :overridden_by,  presence: true
end
