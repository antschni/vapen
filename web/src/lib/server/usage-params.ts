import type { components } from "#lib/api/schema.d.ts";
import {
  rangeFromPreset,
  toIso,
  type RangePreset,
} from "#lib/server/ranges.js";

export type UsageBucket = components["schemas"]["UsageBucket"];

const PRESETS: RangePreset[] = ["today", "7d", "30d", "90d", "year", "custom"];
const BUCKETS: UsageBucket[] = ["hour", "day", "week", "month"];

export type UsageFilters = {
  preset: RangePreset;
  bucket: UsageBucket;
  deviceId?: string;
  userId?: string;
  fromIso: string;
  toIso: string;
  minDurationMs?: number;
  maxDurationMs?: number;
};

export function parseUsageFilters(
  url: URL,
  tz: string,
  selfUserId: string,
): UsageFilters {
  const presetRaw = url.searchParams.get("preset") ?? "7d";
  const preset = PRESETS.includes(presetRaw as RangePreset)
    ? (presetRaw as RangePreset)
    : "7d";
  const bucketRaw = url.searchParams.get("bucket") ?? "day";
  const bucket = BUCKETS.includes(bucketRaw as UsageBucket)
    ? (bucketRaw as UsageBucket)
    : "day";
  const deviceId = url.searchParams.get("device_id")?.trim() || undefined;
  const userIdParam = url.searchParams.get("user_id")?.trim();
  const userId =
    userIdParam && userIdParam !== selfUserId ? userIdParam : undefined;
  const customFrom = url.searchParams.get("from") ?? undefined;
  const customTo = url.searchParams.get("to") ?? undefined;
  const minRaw = url.searchParams.get("min_duration_ms");
  const maxRaw = url.searchParams.get("max_duration_ms");
  const minDurationMs = minRaw ? Number.parseInt(minRaw, 10) : undefined;
  const maxDurationMs = maxRaw ? Number.parseInt(maxRaw, 10) : undefined;

  const { from, to } = rangeFromPreset(preset, tz, customFrom, customTo);

  return {
    preset,
    bucket,
    deviceId,
    userId,
    fromIso: toIso(from),
    toIso: toIso(to),
    minDurationMs: Number.isFinite(minDurationMs) ? minDurationMs : undefined,
    maxDurationMs: Number.isFinite(maxDurationMs) ? maxDurationMs : undefined,
  };
}

export function usageFiltersToSearchParams(
  filters: UsageFilters,
  selfUserId: string,
): URLSearchParams {
  const params = new URLSearchParams();
  params.set("preset", filters.preset);
  params.set("bucket", filters.bucket);
  if (filters.deviceId) params.set("device_id", filters.deviceId);
  if (filters.userId && filters.userId !== selfUserId)
    params.set("user_id", filters.userId);
  if (filters.preset === "custom") {
    params.set("from", filters.fromIso);
    params.set("to", filters.toIso);
  }
  if (filters.minDurationMs !== undefined)
    params.set("min_duration_ms", String(filters.minDurationMs));
  if (filters.maxDurationMs !== undefined)
    params.set("max_duration_ms", String(filters.maxDurationMs));
  return params;
}
