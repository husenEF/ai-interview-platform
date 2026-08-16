import { Card, CardContent } from "@/components/ui/card";
import LevelBadge from "./LevelBadge";
import ConfidenceIndicator from "./ConfidenceIndicator";
import OverridePanel from "./OverridePanel";
import { Zap, HelpCircle } from "lucide-react";
import {
  parseLevel,
  NOT_ASSESSED_DESCRIPTIONS,
  NOT_ASSESSED_FALLBACK_DESCRIPTION,
} from "@/utils/constants";
import type { PortfolioSkill, AssessorOverride } from "@/types";

interface SkillPortfolioCardProps {
  skill: PortfolioSkill;
  override?: AssessorOverride;
  onOverrideSaved: (override: AssessorOverride) => void;
}

export default function SkillPortfolioCard({
  skill,
  override,
  onOverrideSaved,
}: SkillPortfolioCardProps) {
  // Both halves can be absent now, and null means "no level" rather than a
  // level of zero — so the assessor's judgement is preferred only when they
  // actually made one.
  const aiLevel = parseLevel(skill.ai_level);
  const effectiveLevel = override?.override_level ?? aiLevel;

  const notAssessed = aiLevel === null;
  const notAssessedDescription = skill.not_assessed_reason
    ? NOT_ASSESSED_DESCRIPTIONS[skill.not_assessed_reason]
    : NOT_ASSESSED_FALLBACK_DESCRIPTION;

  return (
    <Card>
      <CardContent className="p-4 space-y-4">
        {/* Skill header */}
        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div className="flex items-start gap-3 min-w-0">
            <LevelBadge level={effectiveLevel} />
            <div className="space-y-0.5 min-w-0">
              <div className="flex flex-wrap items-center gap-1.5">
                <span className="font-semibold break-words">{skill.skill_label}</span>
                {skill.is_discovered && (
                  <span className="flex items-center gap-0.5 text-xs text-amber-600">
                    <Zap className="h-3 w-3" /> Discovered
                  </span>
                )}
              </div>
              <ConfidenceIndicator confidence={skill.ai_confidence} />
            </div>
          </div>
          <OverridePanel skill={skill} existingOverride={override} onSaved={onOverrideSaved} />
        </div>

        {/* Why there is no rating.
            Stated before anything else on the card, because a reader who has
            not registered that this skill was never assessed will read
            everything below it as if it were an evaluation. */}
        {notAssessed && (
          <div className="flex gap-2 text-xs text-muted-foreground bg-muted/50 border border-dashed rounded px-3 py-2">
            <HelpCircle className="h-3.5 w-3.5 shrink-0 mt-0.5" />
            <p>{notAssessedDescription}</p>
          </div>
        )}

        {/* Low confidence note — only meaningful when there is a rating to
            qualify. */}
        {!notAssessed && skill.ai_confidence === "low" && (
          <div className="text-xs text-muted-foreground bg-amber-50 border border-amber-200 rounded px-3 py-2">
            Only briefly explored. Confidence is low — warrants a dedicated session if this skill matters.
          </div>
        )}

        {/* Evidence */}
        {skill.evidence.length > 0 && (
          <div className="space-y-1.5">
            <span className="text-xs font-medium text-muted-foreground uppercase tracking-wide">
              Evidence from interview
            </span>
            <ul className="space-y-1">
              {skill.evidence.map((quote, i) => (
                <li key={i} className="text-sm text-foreground line-clamp-3 break-words">
                  • "{quote}"
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* Competency summary. Suppressed when the skill was not assessed —
            the reason above already says everything true about it, and a
            second paragraph reads like an evaluation. */}
        {!notAssessed && skill.competency_summary && (
          <div className="space-y-1">
            <span className="text-xs font-medium text-muted-foreground uppercase tracking-wide">
              Competency summary
            </span>
            <p className="text-sm text-muted-foreground leading-relaxed line-clamp-4 break-words">
              {skill.competency_summary}
            </p>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
