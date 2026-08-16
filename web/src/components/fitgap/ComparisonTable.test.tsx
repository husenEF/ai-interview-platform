import { describe, it, expect } from "vitest";
import { render, screen, within } from "@testing-library/react";
import ComparisonTable from "./ComparisonTable";
import type { SkillComparison } from "@/types";

// Shaped after an actual response from FitGap::Engine rather than after the
// old type — that mismatch is what this file exists to catch.
const COMPARISONS: SkillComparison[] = [
  {
    skill_label: "Node.js / Backend Development",
    skill_id: "SK-ENG-002",
    candidate_level: 4,
    expected_level: 4,
    result: "match",
    delta: 0,
    confidence: "high",
    is_override: false,
  },
  {
    skill_label: "Database Design & SQL",
    skill_id: "SK-ENG-004",
    candidate_level: 2,
    expected_level: 3,
    result: "gap",
    delta: -1,
    confidence: "low",
    is_override: false,
  },
  {
    skill_label: "Testing & Quality Assurance",
    skill_id: "SK-ENG-006",
    candidate_level: 4,
    expected_level: 4,
    result: "match",
    delta: 0,
    confidence: "medium",
    is_override: true,
  },
  {
    skill_label: "System Design & Architecture",
    skill_id: "SK-ENG-003",
    candidate_level: null,
    expected_level: 4,
    result: "not_assessed",
    delta: null,
    confidence: null,
    is_override: false,
  },
];

function rowFor(label: string) {
  return screen.getByText(label).closest("tr") as HTMLElement;
}

describe("ComparisonTable", () => {
  // The table read `required_level` while the API sent `expected_level`, so
  // every Required cell rendered LEVEL_LABELS[undefined] — blank. A reader saw
  // "Gap -1" with no target to check it against.
  it("shows the level the role requires on every row", () => {
    render(<ComparisonTable comparisons={COMPARISONS} />);

    expect(within(rowFor("Database Design & SQL")).getByText("L3")).toBeInTheDocument();
    expect(within(rowFor("System Design & Architecture")).getByText("L4")).toBeInTheDocument();
  });

  it("marks a level the assessor set rather than the AI", () => {
    render(<ComparisonTable comparisons={COMPARISONS} />);

    expect(within(rowFor("Testing & Quality Assurance")).getByText("✏")).toBeInTheDocument();
    expect(within(rowFor("Node.js / Backend Development")).queryByText("✏")).not.toBeInTheDocument();
  });

  it("says a skill was not assessed instead of leaving a bare dash", () => {
    render(<ComparisonTable comparisons={COMPARISONS} />);

    expect(within(rowFor("System Design & Architecture")).getByText("not assessed"))
      .toBeInTheDocument();
  });

  // A verdict drawn from part of the picture has to say how much is missing;
  // the summary used to count only the three outcomes that carry a verdict.
  it("counts the unassessed skills alongside match and gap", () => {
    render(<ComparisonTable comparisons={COMPARISONS} />);

    expect(screen.getByText(/Not assessed: 1 skill/)).toBeInTheDocument();
    expect(screen.getByText(/1 of 4 required skills were not assessed/)).toBeInTheDocument();
  });
});
