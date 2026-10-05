import { de as dateFnsDe } from "date-fns/locale";
import { formatDistanceStrict } from "date-fns";

const numberFormatter = new Intl.NumberFormat("de-DE");

export function formatNumber(value: number): string {
  return numberFormatter.format(value);
}

function formatSeconds(ms: number): string {
  const whole = Math.floor(ms / 1000);
  const fraction = ms % 1000;
  if (fraction === 0) return `${whole} s`;
  const digits = String(fraction).padStart(3, "0").replace(/0+$/, "");
  return `${whole},${digits} s`;
}

export function formatDurationMs(ms: number): string {
  if (!Number.isFinite(ms) || ms <= 0) return "0 s";
  const total = Math.floor(ms);
  const hours = Math.floor(total / 3_600_000);
  const minutes = Math.floor((total % 3_600_000) / 60_000);
  const remainder = total % 60_000;

  if (hours > 0) {
    const parts = [`${hours} Std.`];
    if (minutes > 0) parts.push(`${minutes} Min.`);
    if (remainder > 0) parts.push(formatSeconds(remainder));
    return parts.join(" ");
  }
  if (minutes > 0) {
    if (remainder > 0) return `${minutes} Min. ${formatSeconds(remainder)}`;
    return `${minutes} Min.`;
  }
  return formatSeconds(total);
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
