import { useCallback, useEffect, useMemo, useState } from "react";
import { sessionsApi } from "@/services/sessions";
import { usePolling } from "./usePolling";
import type { AssessorOverride, NotAssessedReason, Portfolio } from "@/types";

const POLL_INTERVAL_MS = 5000;

export interface PortfolioCoverage {
  total: number;
  assessed: number;
  notAssessed: number;
  /** How many skills fall under each reason, so the page can name the causes
   *  rather than reporting a bare count. */
  reasons: Record<NotAssessedReason, number>;
  /** True when there is something to assess and part of it has no rating. */
  partial: boolean;
}

/**
 * Owns fetching, polling and override bookkeeping for one session's portfolio.
 *
 * Extracted from PortfolioPage so the page is a rendering decision and the
 * states below can be tested without a browser — the page previously held all
 * of this inline and reached for `res.data as any` to get past the response
 * union.
 */
export function usePortfolioReport(sessionId: number) {
  const [portfolio, setPortfolio] = useState<Portfolio | null>(null);
  const [overrides, setOverrides] = useState<Record<number, AssessorOverride>>({});
  const [generating, setGenerating] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchPortfolio = useCallback(async () => {
    try {
      const res = await sessionsApi.getPortfolio(sessionId);
      const data = res.data;

      // Narrowed on the shape the API documents instead of cast away. The
      // endpoint answers either {status: "generating"} or {portfolio: {...}},
      // and `as any` made both look like the second one.
      if (!("portfolio" in data)) {
        setGenerating(true);
        return;
      }

      const { portfolio: next } = data;

      if (next.generation_status === "generating" || next.generation_status === "pending") {
        setGenerating(true);
        return;
      }

      setPortfolio(next);
      setGenerating(false);
      setError(null);
      setOverrides(
        Object.fromEntries(next.overrides.map((o) => [o.portfolio_skill_id, o]))
      );
    } catch {
      // A failed fetch is not a failed generation. Conflating them told the
      // assessor the AI had given up when the network had.
      setError("Could not load this portfolio. Check your connection and try again.");
    }
  }, [sessionId]);

  useEffect(() => {
    fetchPortfolio().finally(() => setLoading(false));
  }, [fetchPortfolio]);

  usePolling(fetchPortfolio, POLL_INTERVAL_MS, generating);

  const regenerate = useCallback(async () => {
    setError(null);
    try {
      await sessionsApi.regeneratePortfolio(sessionId);
      setGenerating(true);
    } catch {
      setError("Could not start regeneration. Please try again.");
    }
  }, [sessionId]);

  const applyOverride = useCallback((skillId: number, override: AssessorOverride) => {
    setOverrides((prev) => ({ ...prev, [skillId]: override }));
  }, []);

  const coverage = useMemo<PortfolioCoverage>(() => {
    const skills = portfolio?.skills ?? [];
    const reasons: Record<NotAssessedReason, number> = {
      never_probed: 0,
      insufficient_evidence: 0,
      analysis_failed: 0,
    };

    let notAssessed = 0;
    skills.forEach((skill) => {
      if (skill.ai_level !== null) return;
      notAssessed += 1;
      if (skill.not_assessed_reason) reasons[skill.not_assessed_reason] += 1;
    });

    return {
      total: skills.length,
      assessed: skills.length - notAssessed,
      notAssessed,
      reasons,
      partial: notAssessed > 0,
    };
  }, [portfolio]);

  return {
    portfolio,
    overrides,
    coverage,
    loading,
    generating,
    error,
    refresh: fetchPortfolio,
    regenerate,
    applyOverride,
  };
}
