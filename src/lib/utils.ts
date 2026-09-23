import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

const ORDINAL_SUFFIX = ["th", "st", "nd", "rd"] as const;
function ordinal(n: number): string {
  const v = n % 100;
  return `${n}${ORDINAL_SUFFIX[(v - 20) % 10] ?? ORDINAL_SUFFIX[v] ?? ORDINAL_SUFFIX[0]}`;
}

/**
 * Human-readable grade level label.
 * 7–10 → "Grade 7" .. "Grade 10" (JHS)
 * 11–12 → "Grade 11" .. "Grade 12" (SHS)
 * 13–16 → "1st Year" .. "4th Year" (College)
 */
export function gradeLevelLabel(level: number | null | undefined, short = false): string {
  if (level == null) return "—";
  if (level <= 12) return short ? `G${level}` : `Grade ${level}`;
  const yr = level - 12;
  return short ? `${ordinal(yr)} Yr` : `${ordinal(yr)} Year`;
}
