import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import ConfidenceIndicator from "./ConfidenceIndicator";

describe("ConfidenceIndicator", () => {
  it.each([
    ["high", "HIGH"],
    ["medium", "MEDIUM"],
    ["low", "LOW"],
  ] as const)("renders %s confidence", (value, label) => {
    render(<ConfidenceIndicator confidence={value} />);

    expect(screen.getByText(`Confidence: ${label}`)).toBeInTheDocument();
  });

  // getLabel used to fall through to "LOW" for anything unrecognised, which
  // now includes null. Rendering "Confidence: LOW" for a skill that carries no
  // rating states something about the candidate that no analysis produced —
  // and low confidence reads as a weak signal, not as an absent one.
  it("renders nothing when there is no confidence to report", () => {
    const { container } = render(<ConfidenceIndicator confidence={null} />);

    expect(container).toBeEmptyDOMElement();
  });
});
