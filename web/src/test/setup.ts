// Registers the jest-dom matchers (toBeInTheDocument, toHaveClass, ...) with
// Vitest's expect, and brings their type augmentation with it. Lives under
// src/ so tsconfig.json's `include: ["src"]` typechecks it.
import "@testing-library/jest-dom/vitest";
import { cleanup } from "@testing-library/react";
import { afterEach } from "vitest";

// Vitest does not unmount React trees between tests on its own. Without this,
// a query like getByRole would match an element left behind by an earlier test.
afterEach(() => {
    cleanup();
});
