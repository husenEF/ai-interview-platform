import {
  LEVEL_LABELS,
  LEVEL_BADGE_CLASSES,
  LEVEL_DESCRIPTIONS,
  NOT_ASSESSED_LABEL,
  NOT_ASSESSED_BADGE_CLASSES,
} from "@/utils/constants";
import { cn } from "@/lib/utils";

interface LevelBadgeProps {
  /** null when the skill carries no rating — rendered as an explicit state, not a blank badge. */
  level: number | null;
  size?: "sm" | "md";
  className?: string;
}

export default function LevelBadge({ level, size = "md", className }: LevelBadgeProps) {
  const assessed = level !== null && level in LEVEL_LABELS;

  return (
    <div
      className={cn(
        "inline-flex flex-col items-center justify-center rounded font-semibold",
        size === "md" ? "px-3 py-2 min-w-14 text-base" : "px-2 py-1 min-w-10 text-sm",
        assessed ? LEVEL_BADGE_CLASSES[level] : NOT_ASSESSED_BADGE_CLASSES,
        // The unassessed label is a phrase, not a two-character code, so it
        // needs room the L1-L5 sizing does not give it.
        !assessed && (size === "md" ? "px-3 py-2 text-xs" : "px-2 py-1 text-[10px]"),
        className
      )}
    >
      {assessed ? (
        <>
          <span>{LEVEL_LABELS[level]}</span>
          {size === "md" && (
            <span className="text-[10px] font-normal opacity-70">
              {LEVEL_DESCRIPTIONS[level]}
            </span>
          )}
        </>
      ) : (
        <span className="whitespace-nowrap font-medium">{NOT_ASSESSED_LABEL}</span>
      )}
    </div>
  );
}
