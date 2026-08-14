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

    // Documents today's behaviour at the seam this branch's API work targets:
    // LEVEL_LABELS is a Record<number, string> with no entry outside 1..5, so
    // an unrated skill renders a silently empty badge rather than saying
    // anything. The frontend slice replaces this with an explicit state.
    it("renders an empty badge when the level is not a rated 1-5 value", () => {
        const { container } = render(<LevelBadge level={0} />);

        expect(container.textContent).toBe("");
    });
});
