import { TZDate } from "@date-fns/tz";
import { format, startOfDay, subDays } from "date-fns";
import { de as dateFnsDe } from "date-fns/locale";
import type { PageServerLoad } from "./$types";
import { toIso } from "#lib/server/ranges.js";
import { de } from "#lib/i18n/de.js";

function chartLabel(iso: string, pattern: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "—";
  return format(date, pattern, { locale: dateFnsDe });
}

export const load: PageServerLoad = async ({ locals, parent }) => {
  const { user, groups } = await parent();
  const tz = user.timezone;
  let now: TZDate;
  try {
    now = new TZDate(new Date(), tz);
  } catch {
    now = new TZDate(new Date(), "UTC");
  }
  const todayStart = startOfDay(now);
  const yesterdayStart = startOfDay(subDays(now, 1));
  const yesterdayEnd = todayStart;

  const statsTz = now.timeZone ?? tz;
  const [todayStats, yesterdayStats, weekStats, devicesRes] = await Promise.all(
    [
      locals.api!.GET("/stats/usage", {
        query: {
          from: toIso(todayStart),
          to: toIso(now),
          bucket: "hour",
          tz: statsTz,
        },
      }),
      locals.api!.GET("/stats/usage", {
        query: {
          from: toIso(yesterdayStart),
          to: toIso(yesterdayEnd),
          bucket: "day",
          tz: statsTz,
        },
      }),
      locals.api!.GET("/stats/usage", {
        query: {
          from: toIso(startOfDay(subDays(now, 6))),
          to: toIso(now),
          bucket: "day",
          tz: statsTz,
        },
      }),
      locals.api!.GET("/devices"),
    ],
  );

  const devices = devicesRes.data ?? [];
  const primaryDevice = devices[0];

  let groupOverview = null;
  const firstGroup = groups[0];
  if (firstGroup) {
    const overview = await locals.api!.GET("/groups/{id}/overview", {
      params: { path: { id: firstGroup.id } },
      query: { tz: statsTz },
    });
    groupOverview = overview.error ? null : (overview.data ?? null);
  }

  const statsFailed =
    Boolean(todayStats.error) ||
    Boolean(yesterdayStats.error) ||
    Boolean(weekStats.error);

  const today = todayStats.error ? null : (todayStats.data ?? null);
  const yesterday = yesterdayStats.error ? null : (yesterdayStats.data ?? null);
  const week = weekStats.error ? null : (weekStats.data ?? null);

  const barPoints =
    week?.series.map((s) => ({
      label: chartLabel(s.bucket_start, "EEE"),
      durationMs: s.total_duration_ms,
      puffCount: s.puff_count,
    })) ?? [];

  const hourlyToday =
    today?.series.map((s) => ({
      label: chartLabel(s.bucket_start, "HH"),
      durationMs: s.total_duration_ms,
      puffCount: s.puff_count,
    })) ?? [];

  const puffDelta =
    today && yesterday
      ? today.totals.puff_count - yesterday.totals.puff_count
      : null;
  const durationDelta =
    today && yesterday
      ? today.totals.total_duration_ms - yesterday.totals.total_duration_ms
      : null;

  const avg7 =
    week && week.series.length > 0
      ? Math.round(
          week.totals.puff_count / Math.max(week.totals.active_days, 1),
        )
      : 0;

  return {
    todayTotals: today?.totals ?? null,
    puffDelta,
    durationDelta,
    avg7,
    lastPuffAt: today?.series.at(-1)?.bucket_start ?? null,
    battery: primaryDevice?.latest_status?.battery_percent ?? null,
    isCharging: primaryDevice?.latest_status?.is_charging ?? false,
    barPoints,
    hourlyToday,
    firstGroupId: firstGroup?.id ?? null,
    groupOverview,
    statsFailed,
    statsErrorMessage: statsFailed ? de.errors.internal : null,
  };
};
