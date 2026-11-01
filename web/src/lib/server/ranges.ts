import { TZDate } from "@date-fns/tz";
import { startOfDay, startOfYear, subDays } from "date-fns";

export type RangePreset = "today" | "7d" | "30d" | "90d" | "year" | "custom";

type Range = { from: Date; to: Date };

// Days to subtract from today so the range covers N calendar days incl. today.
const DAYS_BACK_7D = 6;
const DAYS_BACK_30D = 29;
const DAYS_BACK_90D = 89;

/** Parses a user-supplied date, or null when it is missing or invalid. */
function parseDate(value: string | undefined): Date | null {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

function daysBack(now: TZDate, days: number): Range {
  return { from: startOfDay(subDays(now, days)), to: now };
}

const PRESET_RANGES: Record<
  RangePreset,
  (now: TZDate, customFrom?: string, customTo?: string) => Range
> = {
  today: (now) => ({ from: startOfDay(now), to: now }),
  "7d": (now) => daysBack(now, DAYS_BACK_7D),
  "30d": (now) => daysBack(now, DAYS_BACK_30D),
  "90d": (now) => daysBack(now, DAYS_BACK_90D),
  year: (now) => ({ from: startOfYear(now), to: now }),
  custom: (now, customFrom, customTo) => {
    const from = parseDate(customFrom) ?? daysBack(now, DAYS_BACK_7D).from;
    const to = parseDate(customTo) ?? now;
    // Swap a reversed range instead of sending from > to to the API.
    return from <= to ? { from, to } : { from: to, to: from };
  },
};

export function rangeFromPreset(
  preset: RangePreset,
  tz: string,
  customFrom?: string,
  customTo?: string,
): Range {
  const now = new TZDate(new Date(), tz);
  const build = PRESET_RANGES[preset] ?? PRESET_RANGES["7d"];
  return build(now, customFrom, customTo);
}

export function toIso(d: Date): string {
  return d.toISOString();
}
