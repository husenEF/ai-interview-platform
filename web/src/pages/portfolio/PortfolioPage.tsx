import { useEffect, useState } from "react";
import { useParams, Link, useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import SkillPortfolioCard from "@/components/portfolio/SkillPortfolioCard";
import CoverageBanner from "@/components/portfolio/CoverageBanner";
import { sessionsApi } from "@/services/sessions";
import { vacanciesApi } from "@/services/vacancies";
import { portfoliosApi } from "@/services/portfolios";
import { usePortfolioReport } from "@/hooks/usePortfolioReport";
import { ArrowLeft, Download, Loader2, RefreshCw, Zap, FileText, Inbox } from "lucide-react";
import type { PortfolioSkill, Vacancy } from "@/types";

export default function PortfolioPage() {
  const { id, sessionId } = useParams<{ id: string; sessionId: string }>();
  const navigate = useNavigate();

  const {
    portfolio,
    overrides,
    coverage,
    loading,
    generating,
    error,
    regenerate,
    applyOverride,
  } = usePortfolioReport(Number(sessionId));

  const [vacancies, setVacancies] = useState<Vacancy[]>([]);
  const [selectedVacancy, setSelectedVacancy] = useState<string>("");
  const [exporting, setExporting] = useState<"pdf" | "json" | null>(null);
  const [candidateName, setCandidateName] = useState<string | null>(null);

  useEffect(() => {
    vacanciesApi
      .list()
      .then((res) => setVacancies(res.data.vacancies))
      .catch(() => setVacancies([]));

    sessionsApi
      .get(Number(sessionId))
      .then((res) => setCandidateName(res.data.session.candidate_name ?? null))
      .catch(() => setCandidateName(null));
  }, [sessionId]);

  const handleRunFitGap = () => {
    if (!selectedVacancy || !portfolio) return;
    navigate(`/assessments/${id}/sessions/${sessionId}/fitgap/${selectedVacancy}`);
  };

  const handleExport = async (format: "pdf" | "json") => {
    if (!portfolio) return;
    setExporting(format);
    try {
      const res = await portfoliosApi.exportPortfolio(
        portfolio.id,
        format,
        selectedVacancy ? Number(selectedVacancy) : undefined
      );
      const blob =
        format === "json"
          ? new Blob([JSON.stringify(res.data, null, 2)], { type: "application/json" })
          : new Blob([res.data as BlobPart], { type: "application/pdf" });

      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `portfolio-${sessionId}.${format}`;
      a.click();
      URL.revokeObjectURL(url);
    } finally {
      setExporting(null);
    }
  };

  if (loading) {
    return (
      <div className="max-w-2xl mx-auto space-y-4">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-48 w-full" />
        <Skeleton className="h-48 w-full" />
      </div>
    );
  }

  const configured = portfolio?.skills.filter((s) => !s.is_discovered) ?? [];
  const discovered = portfolio?.skills.filter((s) => s.is_discovered) ?? [];

  const renderSkill = (skill: PortfolioSkill) => (
    <SkillPortfolioCard
      key={skill.id}
      skill={skill}
      override={overrides[skill.id]}
      onOverrideSaved={(o) => applyOverride(skill.id, o)}
    />
  );

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      {/* Header. Wraps on narrow screens — three actions plus a title do not
          fit side by side at 375px. */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex items-center gap-2 min-w-0">
          <Link
            to={`/assessments/${id}/invite`}
            aria-label="Back to assessment"
            className="text-muted-foreground hover:text-foreground shrink-0"
          >
            <ArrowLeft className="h-4 w-4" />
          </Link>
          <div className="min-w-0">
            <h1 className="text-lg font-semibold">Portfolio Results</h1>
            {candidateName && (
              <p className="text-sm text-muted-foreground truncate">{candidateName}</p>
            )}
          </div>
        </div>

        <div className="flex flex-wrap gap-2">
          <Link
            to={`/assessments/${id}/sessions/${sessionId}/transcript`}
            className="inline-flex items-center gap-1 text-sm border rounded-md px-3 py-1.5 hover:bg-accent transition-colors"
          >
            <FileText className="h-3.5 w-3.5" />
            Transcript
          </Link>
          {!generating && portfolio && (
            <>
              <Button variant="outline" size="sm" onClick={() => handleExport("pdf")} disabled={!!exporting}>
                {exporting === "pdf" ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Download className="h-3.5 w-3.5 mr-1" />}
                PDF
              </Button>
              <Button variant="outline" size="sm" onClick={() => handleExport("json")} disabled={!!exporting}>
                {exporting === "json" ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Download className="h-3.5 w-3.5 mr-1" />}
                JSON
              </Button>
            </>
          )}
        </div>
      </div>

      {/* Fetch failure — distinct from a failed generation. */}
      {error && (
        <div className="border border-destructive/40 rounded-lg p-4 text-sm text-destructive">
          {error}
        </div>
      )}

      {/* Generating */}
      {generating && (
        <div className="border rounded-lg p-12 text-center space-y-3">
          <Loader2 className="h-8 w-8 animate-spin text-primary mx-auto" />
          <div>
            <p className="font-medium">Generating portfolio...</p>
            <p className="text-sm text-muted-foreground mt-1">
              The AI is analyzing the interview transcript. This takes about 2 minutes.
            </p>
          </div>
        </div>
      )}

      {/* Generation failed. The error is quoted rather than swallowed: without
          it an assessor cannot tell a transient timeout from a broken
          configuration, and has nothing to paste when asking for help. */}
      {!generating && portfolio?.generation_status === "failed" && (
        <div className="border border-destructive/40 rounded-lg p-6 space-y-3">
          <div className="space-y-1">
            <p className="text-sm font-medium text-destructive">Portfolio generation failed.</p>
            {portfolio.generation_error && (
              <p className="text-xs text-muted-foreground break-words font-mono">
                {portfolio.generation_error}
              </p>
            )}
          </div>
          <Button variant="outline" size="sm" onClick={regenerate}>
            <RefreshCw className="h-3.5 w-3.5 mr-1.5" /> Retry
          </Button>
        </div>
      )}

      {/* Ready */}
      {!generating && portfolio?.generation_status === "complete" && (
        <>
          <CoverageBanner coverage={coverage} />

          {portfolio.skills.length === 0 ? (
            // An interview that produced no skills at all is a real outcome —
            // a session ended early, or the coverage analyzer never ran. The
            // page used to render an empty "Configured Skills" heading and
            // leave the reader to guess whether it was still loading.
            <div className="border border-dashed rounded-lg p-10 text-center space-y-2">
              <Inbox className="h-8 w-8 text-muted-foreground mx-auto" />
              <p className="font-medium">No skills in this portfolio</p>
              <p className="text-sm text-muted-foreground">
                The interview did not produce any skill assessments. Check the transcript to see
                how far the session got.
              </p>
              {/* No Regenerate button here on purpose. The API allows regeneration
                  only from a `failed` status, so on a portfolio that generated
                  successfully and simply found nothing, the button would offer an
                  action that always fails. An offer the product cannot honour is
                  worse than no offer. */}
            </div>
          ) : (
            <>
              {configured.length > 0 && (
                <div className="space-y-3">
                  <h2 className="text-sm font-semibold">Configured Skills</h2>
                  {configured.map(renderSkill)}
                </div>
              )}

              {discovered.length > 0 && (
                <>
                  <Separator />
                  <div className="space-y-3">
                    <div>
                      <h2 className="text-sm font-semibold flex items-center gap-1.5">
                        <Zap className="h-4 w-4 text-amber-500" />
                        Discovered Skills
                      </h2>
                      <p className="text-xs text-muted-foreground">
                        Skills the AI probed that were not in the original assessment
                      </p>
                    </div>
                    {discovered.map(renderSkill)}
                  </div>
                </>
              )}

              <Separator />

              {/* Fit/Gap */}
              <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
                <Select value={selectedVacancy} onValueChange={setSelectedVacancy}>
                  <SelectTrigger className="w-full sm:w-56">
                    <SelectValue placeholder="Choose vacancy..." />
                  </SelectTrigger>
                  <SelectContent>
                    {vacancies.map((v) => (
                      <SelectItem key={v.id} value={String(v.id)}>
                        {v.role_title}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <Button onClick={handleRunFitGap} disabled={!selectedVacancy}>
                  Run Fit/Gap Analysis →
                </Button>
              </div>
            </>
          )}
        </>
      )}
    </div>
  );
}
