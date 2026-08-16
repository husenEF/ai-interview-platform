import { describe, it, expect } from "vitest";
import { parseLevel } from "./constants";

describe("parseLevel", () => {
  it("passes a rated level through", () => {
    expect(parseLevel(3)).toBe(3);
  });

  // The API has always sent ai_level as a number. The "L3" string form this
  // function was written to parse appears nowhere in the payload — but the
  // branch is kept because assessment fixtures and older exports still use it.
  it("parses the L-prefixed string form", () => {
    expect(parseLevel("L4")).toBe(4);
  });

  // This is the frontend half of the defect the API branch fixed. The backend
  // did `skill_data['level'].to_i.clamp(1, 5)`; here it is `isNaN(n) ? 1 : n`.
  // Two independent code paths, both turning "we have no rating" into Level 1 —
  // the lowest score on the scale, shown to a recruiter as a real judgement
  // about a candidate who may never have been asked the question.
  describe("when there is no usable level", () => {
    const cases: Array<[string, unknown]> = [
      ["null", null],
      ["undefined", undefined],
      ["an empty string", ""],
      ["prose", "abc"],
      ["a zero", 0],
      ["a negative", -1],
      ["above the scale", 99],
    ];

    cases.forEach(([label, input]) => {
      it(`returns null rather than inventing a level from ${label}`, () => {
        expect(parseLevel(input as never)).toBeNull();
      });
    });
  });

  // Before this branch, ai_level was typed `string` while the API sent a
  // number, so nobody had reason to think null could arrive. It can now, and
  // `null.replace(...)` would take the whole portfolio page down.
  it("does not throw on the value the API actually sends for an unassessed skill", () => {
    expect(() => parseLevel(null as never)).not.toThrow();
  });
});
