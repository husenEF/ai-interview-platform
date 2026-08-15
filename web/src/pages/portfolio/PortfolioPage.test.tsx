import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import PortfolioPage from "./PortfolioPage";
import { makeSkill, makeUnassessedSkill } from "@/test/factories";
import type { Portfolio } from "@/types";

vi.mock("react-router-dom", async () => {
  const actual = await vi.importActual<typeof import("react-router-dom")>("react-router-dom");
  return { ...actual, useParams: () => ({ id: "1", sessionId: "1" }), useNavigate: () => vi.fn() };
});

const getPortfolio = vi.fn();
const getSession = vi.fn();
const listVacancies = vi.fn();

vi.mock("@/services/sessions", () => ({
  sessionsApi: {
    getPortfolio: (...args: unknown[]) => getPortfolio(...args),
    get: (...args: unknown[]) => getSession(...args),
    regeneratePortfolio: vi.fn().mockResolvedValue({ data: {} }),
  },
}));

vi.mock("@/services/vacancies", () => ({
  vacanciesApi: { list: (...args: unknown[]) => listVacancies(...args) },
}));

vi.mock("@/services/portfolios", () => ({
  portfoliosApi: { exportPortfolio: vi.fn(), getOverride: vi.fn() },
}));

function makePortfolio(overrides: Partial<Portfolio> = {}): Portfolio {
  return {
    id: 1,
    session_id: 1,
    candidate_id: 42,
    generation_status: "complete",
    generated_at: "2026-08-16T00:00:00Z",
    skills: [makeSkill()],
    overrides: [],
    ...overrides,
  };
}

function renderPage() {
  return render(
    <MemoryRouter>
      <PortfolioPage />
    </MemoryRouter>
  );
}

beforeEach(() => {
  vi.clearAllMocks();
  listVacancies.mockResolvedValue({ data: { vacancies: [] } });
  getSession.mockResolvedValue({ data: { session: { candidate_name: "Candidate Example" } } });
  getPortfolio.mockResolvedValue({ data: { portfolio: makePortfolio() } });
});

describe("PortfolioPage", () => {
  it("shows a skeleton while the first fetch is in flight", () => {
    getPortfolio.mockReturnValue(new Promise(() => {}));

    const { container } = renderPage();

    expect(container.querySelectorAll("[data-slot='skeleton'], .animate-pulse").length)
      .toBeGreaterThan(0);
  });

  it("renders the skills once loaded", async () => {
    renderPage();

    expect(await screen.findByText("Debugging")).toBeInTheDocument();
  });

  it("tells the reader the interview produced nothing rather than showing a bare heading", async () => {
    getPortfolio.mockResolvedValue({ data: { portfolio: makePortfolio({ skills: [] }) } });

    renderPage();

    expect(await screen.findByText(/no skills/i)).toBeInTheDocument();
  });

  // The failed block existed but discarded generation_error, so an assessor was
  // told "generation failed" with no way to tell a transient timeout from a
  // misconfigured model — and nothing to quote when asking for help.
  it("shows why generation failed, not just that it did", async () => {
    getPortfolio.mockResolvedValue({
      data: {
        portfolio: makePortfolio({
          generation_status: "failed",
          generation_error: "Gemini API timeout after 180s",
        }),
      },
    });

    renderPage();

    expect(await screen.findByText(/timeout after 180s/i)).toBeInTheDocument();
  });

  it("keeps polling visible while the portfolio is still generating", async () => {
    getPortfolio.mockResolvedValue({ data: { status: "generating" } });

    renderPage();

    expect(await screen.findByText(/generating portfolio/i)).toBeInTheDocument();
  });

  // The state this whole branch exists for. A portfolio where half the skills
  // carry no rating still renders as a complete-looking report, and a recruiter
  // scanning it has no reason to scroll far enough to notice.
  describe("when part of the assessment produced no rating", () => {
    beforeEach(() => {
      getPortfolio.mockResolvedValue({
        data: {
          portfolio: makePortfolio({
            skills: [
              makeSkill({ id: 1, skill_label: "Debugging" }),
              makeUnassessedSkill({ id: 2, skill_label: "Testing" }),
              makeUnassessedSkill({
                id: 3,
                skill_label: "System Design",
                not_assessed_reason: "analysis_failed",
              }),
            ],
          }),
        },
      });
    });

    it("says up front how many skills were not assessed", async () => {
      renderPage();

      const banner = await screen.findByRole("status");
      expect(banner).toHaveTextContent(/2 of 3/i);
      expect(banner).toHaveTextContent(/not assessed/i);
    });

    it("does not show the banner when everything was assessed", async () => {
      getPortfolio.mockResolvedValue({ data: { portfolio: makePortfolio() } });

      renderPage();
      await screen.findByText("Debugging");

      expect(screen.queryByRole("status")).not.toBeInTheDocument();
    });

    it("names the analysis failure separately from the unasked skills", async () => {
      renderPage();

      const banner = await screen.findByRole("status");
      await waitFor(() => expect(banner).toHaveTextContent(/could not be analyzed/i));
      expect(banner).toHaveTextContent(/never came up/i);
    });
  });
});
