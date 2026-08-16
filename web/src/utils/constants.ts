import type { NotAssessedReason } from "@/types";

export const TIME_LIMIT_OPTIONS = [10, 30, 45, 60, 90] as const;

/**
 * Parse "L3" → 3, pass a number through, and return null when there is no
 * level on the 1..5 scale.
 *
 * It returns null rather than falling back, because the fallback used to be
 * `isNaN(n) ? 1 : n` — the client half of a defect the API had too
 * (`skill_data['level'].to_i.clamp(1, 5)`). Two independent code paths turned
 * "we have no rating" into Level 1: the lowest score on the scale, shown to a
 * recruiter as a real judgement about a candidate who may never have been
 * asked. Absence is not a low score, and callers have to handle it as absence.
 */
export function parseLevel(level: string | number | null | undefined): number | null {
  if (level === null || level === undefined) return null;

  const n = typeof level === "number" ? level : parseInt(level.replace(/\D/g, ""), 10);

  return Number.isInteger(n) && n >= 1 && n <= 5 ? n : null;
}

export const LEVEL_LABELS: Record<number, string> = {
  1: "L1",
  2: "L2",
  3: "L3",
  4: "L4",
  5: "L5",
};

export const LEVEL_DESCRIPTIONS: Record<number, string> = {
  1: "Foundational",
  2: "Functional",
  3: "Proficient",
  4: "Advanced",
  5: "Expert",
};

// Shown in place of a level. Written as sentences a recruiter can act on,
// not as enum names: the reason is the whole point of keeping three of them.
export const NOT_ASSESSED_LABEL = "Not assessed";

export const NOT_ASSESSED_DESCRIPTIONS: Record<NotAssessedReason, string> = {
  never_probed:
    "This skill was not discussed during the interview, so there is nothing to assess it from.",
  insufficient_evidence:
    "The interview did not produce enough evidence to rate this skill.",
  analysis_failed:
    "Automated analysis did not complete for this skill. This does not mean it was not discussed.",
};

/** Fallback for a skill with no level and no reason — the API should not
 *  produce this (a check constraint forbids it), but the UI must not go blank
 *  if it ever does. */
export const NOT_ASSESSED_FALLBACK_DESCRIPTION =
  "No rating is available for this skill.";

// Deliberately not a neutral fill: L1 is `bg-neutral-200`, and an unassessed
// skill that reads as a muted grey chip is exactly the confusion this state
// exists to remove. A dashed outline reads as "nothing here", not "lowest".
export const NOT_ASSESSED_BADGE_CLASSES =
  "border border-dashed border-muted-foreground/50 bg-transparent text-muted-foreground";

// L-badge colors (Tailwind classes)
export const LEVEL_BADGE_CLASSES: Record<number, string> = {
  1: "bg-neutral-200 text-neutral-700",
  2: "bg-blue-100 text-blue-700",
  3: "bg-teal-100 text-teal-700",
  4: "bg-purple-100 text-purple-700",
  5: "bg-yellow-100 text-yellow-700",
};

// Coverage state display
export const COVERAGE_STATE_LABELS: Record<string, string> = {
  not_yet: "not yet",
  initiated: "initiated",
  partial: "partial",
  covered: "covered",
};

export const COVERAGE_STATE_WIDTH: Record<string, number> = {
  not_yet: 0,
  initiated: 25,
  partial: 60,
  covered: 100,
};

export const COVERAGE_STATE_COLOR: Record<string, string> = {
  not_yet: "bg-neutral-200",
  initiated: "bg-blue-300",
  partial: "bg-teal-400",
  covered: "bg-teal-600",
};

// Fit/Gap result display
export const FIT_GAP_RESULT_LABELS: Record<string, string> = {
  match: "Match",
  gap: "Gap",
  exceed: "Exceeds",
  not_assessed: "Not assessed",
};

export const FIT_GAP_RESULT_CLASSES: Record<string, string> = {
  match: "text-green-700 bg-green-50",
  gap: "text-amber-700 bg-amber-50",
  exceed: "text-green-700 bg-green-50",
  not_assessed: "text-neutral-500 bg-neutral-50",
};
