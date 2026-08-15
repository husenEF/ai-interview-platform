import type { AssessorOverride, PortfolioSkill } from "@/types";

/**
 * A skill the interview assessed. Overrides are shallow-merged so a test can
 * state only the field it is about.
 */
export function makeSkill(overrides: Partial<PortfolioSkill> = {}): PortfolioSkill {
  return {
    id: 1,
    skill_id: "SK-ENG-001",
    skill_label: "Debugging",
    is_discovered: false,
    ai_level: 3,
    ai_confidence: "high",
    not_assessed_reason: null,
    evidence: ["I bisected the commit range before touching the code."],
    competency_summary: "Narrows the search space before changing anything.",
    ...overrides,
  };
}

/**
 * A skill carrying no rating. ai_level and ai_confidence are both cleared:
 * the database enforces that pairing with a XOR check constraint, so a fixture
 * that sets only the reason would describe a row the API cannot produce.
 */
export function makeUnassessedSkill(
  overrides: Partial<PortfolioSkill> = {}
): PortfolioSkill {
  return makeSkill({
    ai_level: null,
    ai_confidence: null,
    not_assessed_reason: "never_probed",
    evidence: [],
    competency_summary:
      "This skill was not discussed during the interview, so there is no evidence to assess it from.",
    ...overrides,
  });
}

export function makeOverride(overrides: Partial<AssessorOverride> = {}): AssessorOverride {
  return {
    id: 1,
    portfolio_skill_id: 1,
    ai_level: 3,
    override_level: 4,
    assessor_notes: "Underrated — the incident story shows clear systems thinking.",
    overridden_by: 1,
    overridden_at: "2026-08-16T00:00:00Z",
    ...overrides,
  };
}
