import { TZDate } from "@date-fns/tz";
import { startOfDay, startOfYear, subDays } from "date-fns";

export type RangePreset = "today" | "7d" | "30d" | "90d" | "year" | "custom";

export function rangeFromPreset(
  preset: RangePreset,
  tz: string,
  customFrom?: string,
  customTo?: string,
): { from: Date; to: Date } {
  const now = new TZDate(new Date(), tz);
  const to = now;

  switch (preset) {
    case "today":
      return { from: startOfDay(now), to };
    case "7d":
      return { from: startOfDay(subDays(now, 6)), to };
    case "30d":
      return { from: startOfDay(subDays(now, 29)), to };
    case "90d":
      return { from: startOfDay(subDays(now, 89)), to };
    case "year":
      return { from: startOfYear(now), to };
    case "custom": {
      const from = customFrom
        ? new Date(customFrom)
        : startOfDay(subDays(now, 6));
      const customEnd = customTo ? new Date(customTo) : to;
      return { from, to: customEnd };
    }
    default:
      return { from: startOfDay(subDays(now, 6)), to };
  }
}

export function toIso(d: Date): string {
  return d.toISOString();
}
