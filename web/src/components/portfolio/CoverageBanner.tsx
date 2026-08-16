import { AlertTriangle } from "lucide-react";
import type { PortfolioCoverage } from "@/hooks/usePortfolioReport";
import type { NotAssessedReason } from "@/types";

interface CoverageBannerProps {
  coverage: PortfolioCoverage;
}

// Phrased from the reader's side: what is missing from the report in front of
// them, not what the pipeline did.
const REASON_PHRASES: Record<NotAssessedReason, (n: number) => string> = {
  never_probed: (n) => `${n} never came up in the interview`,
  insufficient_evidence: (n) => `${n} did not produce enough evidence to rate`,
  // "analyzed", matching the existing copy on this page ("The AI is analyzing
  // the interview transcript").
  analysis_failed: (n) =>
    `${n} could not be analyzed — this does not mean they were not discussed`,
};

/**
 * Shown when part of an assessment carries no rating.
 *
 * Without it a portfolio missing half its skills renders as an ordinary,
 * complete-looking report: the gaps are visible only to a reader who scrolls
 * every card and notices the absence. A hiring decision made from the top of
 * this page has to know how much of it is missing.
 */
export default function CoverageBanner({ coverage }: CoverageBannerProps) {
  if (!coverage.partial) return null;

  const phrases = (Object.entries(coverage.reasons) as Array<[NotAssessedReason, number]>)
    .filter(([, count]) => count > 0)
    .map(([reason, count]) => REASON_PHRASES[reason](count));

  return (
    <div
      role="status"
      className="flex gap-3 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm dark:border-amber-900/50 dark:bg-amber-950/30"
    >
      <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0 text-amber-600" aria-hidden />
      <div className="space-y-1">
        <p className="font-medium">
          {coverage.notAssessed} of {coverage.total} skill
          {coverage.total === 1 ? "" : "s"} {coverage.notAssessed === 1 ? "was" : "were"} not
          assessed
        </p>
        {phrases.length > 0 && (
          <p className="text-muted-foreground">
            {phrases.join("; ")}.
          </p>
        )}
        <p className="text-muted-foreground">
          Treat this as a partial picture. An unassessed skill is not a low score.
        </p>
      </div>
    </div>
  );
}
