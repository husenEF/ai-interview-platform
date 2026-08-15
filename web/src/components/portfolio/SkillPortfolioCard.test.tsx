import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import SkillPortfolioCard from "./SkillPortfolioCard";
import { makeSkill, makeUnassessedSkill, makeOverride } from "@/test/factories";
import type { NotAssessedReason } from "@/types";

function renderCard(props: Partial<Parameters<typeof SkillPortfolioCard>[0]> = {}) {
  return render(
    <SkillPortfolioCard
      skill={makeSkill()}
      onOverrideSaved={vi.fn()}
      {...props}
    />
  );
}

describe("SkillPortfolioCard", () => {
  describe("a skill the interview assessed", () => {
    it("shows the level and its evidence", () => {
      renderCard();

      expect(screen.getByText("L3")).toBeInTheDocument();
      expect(screen.getByText(/bisected the commit range/)).toBeInTheDocument();
    });

    // The AI's original level stays on screen next to the human one. Replacing
    // it outright would hide that a person disagreed, which is the single most
    // interesting fact on the card.
    it("shows the assessor's level alongside the AI's when overridden", () => {
      renderCard({ override: makeOverride({ ai_level: 3, override_level: 5 }) });

      // L5 appears twice by design — once as the effective level in the header,
      // once inside the "AI L3 → L5" trail in the override panel.
      expect(screen.getAllByText("L5").length).toBeGreaterThan(0);
      expect(screen.getByText("L3")).toBeInTheDocument();
      expect(screen.getByText(/overridden/i)).toBeInTheDocument();
    });
  });

  // The candidate is who this protects. They never chose this product, cannot
  // see the portfolio, and a Level 1 they were never asked to earn follows them
  // into a hiring decision. A recruiter must be able to tell "we did not assess
  // this" apart from "we assessed this and it was weak" at a glance.
  describe("a skill carrying no rating", () => {
    it("shows no level at all rather than the lowest one", () => {
      renderCard({ skill: makeUnassessedSkill() });

      ["L1", "L2", "L3", "L4", "L5"].forEach((label) => {
        expect(screen.queryByText(label)).not.toBeInTheDocument();
      });
    });

    it("says in words that it was not assessed", () => {
      renderCard({ skill: makeUnassessedSkill() });

      expect(screen.getByText(/not assessed/i)).toBeInTheDocument();
    });

    // Three reasons that read very differently to whoever is deciding on this
    // person: nobody asked, we asked and the answer was thin, or our own
    // analysis broke. Collapsing them into one "N/A" throws that away.
    const reasons: Array<[NotAssessedReason, RegExp]> = [
      ["never_probed", /not discussed|never asked|not covered/i],
      ["insufficient_evidence", /enough evidence/i],
      ["analysis_failed", /analysis|did not complete|could not be completed/i],
    ];

    reasons.forEach(([reason, expected]) => {
      it(`explains ${reason} distinctly`, () => {
        renderCard({ skill: makeUnassessedSkill({ not_assessed_reason: reason }) });

        expect(screen.getByText(expected)).toBeInTheDocument();
      });
    });

    it("does not claim a confidence it never had", () => {
      renderCard({ skill: makeUnassessedSkill() });

      expect(screen.queryByText(/confidence/i)).not.toBeInTheDocument();
    });

    it("omits the evidence section instead of showing an empty one", () => {
      renderCard({ skill: makeUnassessedSkill() });

      expect(screen.queryByText(/evidence from interview/i)).not.toBeInTheDocument();
    });

    // The recovery path. A skill the model could not rate is exactly the one an
    // assessor should be able to rate themselves, so the override control has
    // to stay reachable here.
    it("still lets an assessor supply their own judgement", () => {
      renderCard({ skill: makeUnassessedSkill() });

      expect(screen.getByRole("button", { name: /override/i })).toBeInTheDocument();
    });

    // "Not assessed → L4" is the honest rendering: the level on record is the
    // assessor's, and it stays visible that the AI supplied nothing.
    it("shows the assessor's level while keeping the AI's silence visible", () => {
      renderCard({
        skill: makeUnassessedSkill(),
        override: makeOverride({ ai_level: null, override_level: 4 }),
      });

      expect(screen.getAllByText("L4").length).toBeGreaterThan(0);
      expect(screen.getAllByText(/not assessed/i).length).toBeGreaterThan(0);
    });
  });

  describe("long content", () => {
    it("keeps a very long summary from running away with the card", () => {
      const summary = ("A ".repeat(400) + "end.").trim();
      renderCard({ skill: makeSkill({ competency_summary: summary }) });

      expect(screen.getByText(summary).className).toMatch(/line-clamp|truncate|overflow/);
    });

    it("clamps a very long evidence quote too", () => {
      const quote = ("very ".repeat(200) + "long.").trim();
      renderCard({ skill: makeSkill({ evidence: [quote] }) });

      const item = screen.getByText(new RegExp(quote.slice(0, 40)));
      expect(item.className).toMatch(/line-clamp|truncate|overflow/);
    });
  });
});
