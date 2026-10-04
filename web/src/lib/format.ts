import { de as dateFnsDe } from "date-fns/locale";
import { formatDistanceStrict } from "date-fns";

const numberFormatter = new Intl.NumberFormat("de-DE");

export function formatNumber(value: number): string {
  return numberFormatter.format(value);
}

export function formatDurationMs(ms: number): string {
  if (!Number.isFinite(ms) || ms < 0) return "0 s";
  const totalSeconds = Math.round(ms / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  if (hours > 0) {
    const parts = [`${hours} Std.`];
    if (minutes > 0) parts.push(`${minutes} Min.`);
    return parts.join(" ");
  }
  if (minutes > 0) {
    if (seconds > 0) return `${minutes} Min. ${seconds} s`;
    return `${minutes} Min.`;
  }
  if (ms < 1000 && ms > 0) {
    const tenths = (ms / 1000).toFixed(1).replace(".", ",");
    return `${tenths} s`;
  }
  return `${seconds} s`;
}

export function formatRelativeTime(
  iso: string | Date,
  now: Date = new Date(),
): string {
  const date = typeof iso === "string" ? new Date(iso) : iso;
  return formatDistanceStrict(date, now, {
    addSuffix: true,
    locale: dateFnsDe,
  });
}
