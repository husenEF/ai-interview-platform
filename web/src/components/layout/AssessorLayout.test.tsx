import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { Provider, createStore } from "jotai";
import AssessorLayout from "./AssessorLayout";
import { tenantAtom } from "@/stores/tenantAtom";

vi.mock("react-router-dom", async () => {
  const actual = await vi.importActual<typeof import("react-router-dom")>("react-router-dom");
  return { ...actual, useNavigate: () => vi.fn(), Outlet: () => null };
});

function renderLayout() {
  const store = createStore();
  store.set(tenantAtom, { id: "3", name: "Test Corp" });

  return render(
    <Provider store={store}>
      <MemoryRouter>
        <AssessorLayout />
      </MemoryRouter>
    </Provider>
  );
}

describe("AssessorLayout header", () => {
  // The header used to be a fixed-height row of two non-shrinking groups that
  // together needed ~550px, so every page in the app scrolled sideways at
  // 375px. The fix collapses the labels to icons below `sm` — these tests pin
  // the part of that fix that is easy to get wrong: the labels must still be
  // in the accessibility tree, not deleted.
  it("keeps an accessible name on every nav link", () => {
    renderLayout();

    expect(screen.getByRole("link", { name: /assessments/i })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /vacancies/i })).toBeInTheDocument();
  });

  it("keeps an accessible name on the logout control", () => {
    renderLayout();

    expect(screen.getByRole("button", { name: /logout/i })).toBeInTheDocument();
  });

  it("still names the tenant, which is not a detail to drop on a small screen", () => {
    renderLayout();

    expect(screen.getByText(/Tenant: Test Corp/)).toBeInTheDocument();
  });
});
