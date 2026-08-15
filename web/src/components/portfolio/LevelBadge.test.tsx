import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import LevelBadge from "./LevelBadge";

describe("LevelBadge", () => {
    it("renders the label and description for a rated level", () => {
        render(<LevelBadge level={3} />);

        expect(screen.getByText("L3")).toBeInTheDocument();
        expect(screen.getByText("Proficient")).toBeInTheDocument();
    });

    it("omits the description at the small size", () => {
        render(<LevelBadge level={3} size="sm" />);

        expect(screen.getByText("L3")).toBeInTheDocument();
        expect(screen.queryByText("Proficient")).not.toBeInTheDocument();
    });

    it("colours each level distinctly so levels are not read by number alone", () => {
        const { container: one } = render(<LevelBadge level={1} />);
        const { container: five } = render(<LevelBadge level={5} />);

        expect(one.firstElementChild?.className).not.toBe(five.firstElementChild?.className);
    });

    // Replaces an earlier case that documented the old behaviour: LEVEL_LABELS
    // is a Record<number, string> with no entry outside 1..5, so an unrated
    // skill rendered a silently empty badge. An empty badge is worse than no
    // badge — it looks like a rendering fault, and a reader fills the gap with
    // their own assumption about the candidate.
    describe("when there is no level", () => {
        it("says so instead of rendering an empty badge", () => {
            render(<LevelBadge level={null} />);

            expect(screen.getByText(/not assessed/i)).toBeInTheDocument();
        });

        // L1 is the closest thing on screen to "no rating", and it is exactly
        // what this branch exists to stop being confused with one. They must
        // not be distinguishable by shape or colour alone.
        it("does not look like Level 1", () => {
            const { container: unassessed } = render(<LevelBadge level={null} />);
            const { container: levelOne } = render(<LevelBadge level={1} />);

            expect(unassessed.firstElementChild?.className).not.toBe(
                levelOne.firstElementChild?.className
            );
            expect(unassessed.textContent).not.toBe(levelOne.textContent);
        });

        it("carries no numeral a reader could mistake for a score", () => {
            const { container } = render(<LevelBadge level={null} />);

            expect(container.textContent).not.toMatch(/[1-5]/);
        });
    });
});
